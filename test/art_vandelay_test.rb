require "test_helper"

class ArtVandelayTest < ActiveSupport::TestCase
  class VERSION < ArtVandelayTest
    test "it has a version number" do
      assert ArtVandelay::VERSION
    end
  end

  class Setup < ArtVandelayTest
    test "it has the correct default values" do
      filtered_attributes = ArtVandelay.filtered_attributes
      from_address = ArtVandelay.from_address
      in_batches_of = ArtVandelay.in_batches_of

      assert_equal(
        [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn],
        filtered_attributes
      )
      assert_nil from_address
      assert_equal 10000, in_batches_of
    end
  end
end
