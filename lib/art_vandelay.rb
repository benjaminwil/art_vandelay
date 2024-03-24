require "art_vandelay/version"
require "art_vandelay/engine"

module ArtVandelay
  mattr_accessor :filtered_attributes, :from_address, :in_batches_of
  @@filtered_attributes = [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn]
  @@in_batches_of = 10000

  def self.setup
    yield self
  end

  class Error < StandardError
  end
end

require "art_vandelay/export"
require "art_vandelay/import"
