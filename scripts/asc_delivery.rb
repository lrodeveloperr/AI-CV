#!/usr/bin/env ruby

require "json"
require "net/http"
require "open3"
require "uri"

API = "https://api.appstoreconnect.apple.com"
EDITABLE_STATES = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].freeze

def required_env(name)
  value = ENV[name].to_s.strip
  abort "Missing #{name}." if value.empty?
  value
end

KEY_PATH = required_env("ASC_KEY_PATH")
KEY_ID = required_env("ASC_KEY_ID")
ISSUER_ID = required_env("ASC_ISSUER_ID")
APP_ID = required_env("ASC_APP_ID")
BUNDLE_ID = required_env("IOS_BUNDLE_ID")
VERSION = required_env("MARKETING_VERSION")
BUILD_NUMBER = required_env("BUILD_NUMBER")
BETA_GROUP_ID = required_env("BETA_GROUP_ID")
PLATFORM = ENV.fetch("LISTING_PLATFORM", "IOS")

def token
  script = File.expand_path("asc_jwt.rb", __dir__)
  jwt, status = Open3.capture2("ruby", script, KEY_PATH, KEY_ID, ISSUER_ID)
  abort "JWT generation failed." unless status.success?
  jwt.strip
end

def request(method, path, body: nil, allow: [])
  uri = URI.join(API, path)
  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(method)
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json" if body
  req.body = JSON.generate(body) if body
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  return [response.code.to_i, response.body] if response.code.to_i.between?(200, 299) || allow.include?(response.code.to_i)
  abort "App Store Connect #{method.to_s.upcase} #{path} failed with HTTP #{response.code}: #{response.body}"
end

def json_get(path)
  _code, body = request(:get, path)
  JSON.parse(body)
end

app = json_get("/v1/apps/#{APP_ID}")
actual_bundle = app.fetch("data").fetch("attributes").fetch("bundleId")
abort "Mapped app bundle mismatch." unless actual_bundle == BUNDLE_ID

build = nil
40.times do
  query = URI.encode_www_form("filter[app]" => APP_ID, "filter[version]" => BUILD_NUMBER, "limit" => "2")
  matches = json_get("/v1/builds?#{query}").fetch("data")
  abort "Build lookup was ambiguous." if matches.length > 1
  unless matches.empty?
    candidate = matches.first
    state = candidate.fetch("attributes").fetch("processingState", "")
    abort "Apple processing failed for build #{BUILD_NUMBER}." if state == "FAILED"
    if state == "VALID"
      build = candidate
      break
    end
  end
  sleep 45
end
abort "Build #{BUILD_NUMBER} did not finish processing within 30 minutes." unless build
build_id = build.fetch("id")

relationship = { data: [{ type: "builds", id: build_id }] }
request(:post, "/v1/betaGroups/#{BETA_GROUP_ID}/relationships/builds", body: relationship, allow: [409])

query = URI.encode_www_form("filter[platform]" => PLATFORM, "filter[versionString]" => VERSION, "limit" => "20")
versions = json_get("/v1/apps/#{APP_ID}/appStoreVersions?#{query}").fetch("data")
editable = versions.select { |item| EDITABLE_STATES.include?(item.fetch("attributes").fetch("appStoreState")) }
abort "Expected one editable #{PLATFORM} version #{VERSION}; found #{editable.length}." unless editable.length == 1
version_id = editable.first.fetch("id")
request(:patch, "/v1/appStoreVersions/#{version_id}/relationships/build", body: { data: { type: "builds", id: build_id } })

group_builds = json_get("/v1/betaGroups/#{BETA_GROUP_ID}/relationships/builds?limit=200").fetch("data")
abort "Build was not assigned to the mapped beta group." unless group_builds.any? { |item| item.fetch("id") == build_id }
attached = json_get("/v1/appStoreVersions/#{version_id}/relationships/build").fetch("data")
abort "Build was not attached to the matching listing version." unless attached && attached.fetch("id") == build_id

puts JSON.generate({
  app_id: APP_ID,
  bundle_id: BUNDLE_ID,
  version: VERSION,
  build_number: BUILD_NUMBER,
  build_id: build_id,
  beta_group_id: BETA_GROUP_ID,
  listing_version_id: version_id,
  beta_delivery: "verified",
  listing_attachment: "verified"
})
