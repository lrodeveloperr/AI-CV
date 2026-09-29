#!/usr/bin/env ruby

require "base64"
require "json"
require "openssl"

def base64url(value)
  Base64.urlsafe_encode64(value, padding: false)
end

abort "usage: asc_jwt.rb KEY_PATH KEY_ID ISSUER_ID" unless ARGV.length == 3

key_path, key_id, issuer_id = ARGV
now = Time.now.to_i
header = { alg: "ES256", kid: key_id, typ: "JWT" }
payload = { iss: issuer_id, iat: now, exp: now + 600, aud: "appstoreconnect-v1" }
unsigned = [base64url(header.to_json), base64url(payload.to_json)].join(".")

key = OpenSSL::PKey::EC.new(File.read(key_path))
digest = OpenSSL::Digest::SHA256.digest(unsigned)
der_signature = key.dsa_sign_asn1(digest)
sequence = OpenSSL::ASN1.decode(der_signature)
r = sequence.value[0].value.to_s(16).rjust(64, "0")
s = sequence.value[1].value.to_s(16).rjust(64, "0")
raw_signature = [r + s].pack("H*")

puts "#{unsigned}.#{base64url(raw_signature)}"
