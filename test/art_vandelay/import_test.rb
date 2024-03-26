class ArtVandelayImportTest < ActiveSupport::TestCase
  test "it imports data from a CSV string" do
    csv_string = CSV.generate do |csv|
      csv << %w[email password]
      csv << %w[email_1@example.com s3krit]
      csv << %w[email_2@example.com s3kure!]
    end

    assert_difference("User.count", 2) do
      ArtVandelay::Import.new(:users).csv(csv_string)
    end

    user_1 = User.find_by!(email: "email_1@example.com")
    user_2 = User.find_by!(email: "email_2@example.com")

    assert_equal "email_1@example.com", user_1.email
    assert_equal "s3krit", user_1.password
    assert_equal "email_2@example.com", user_2.email
    assert_equal "s3kure!", user_2.password
  end

  test "it imports data from a JSON string" do
    json_string = [
      {email: "email_1@example.com", password: "s3krit"},
      {email: "email_2@example.com", password: "s3kure!"}
    ].to_json

    assert_difference("User.count", 2) do
      ArtVandelay::Import.new(:users).json(json_string)
    end

    user_1 = User.find_by!(email: "email_1@example.com")
    user_2 = User.find_by!(email: "email_2@example.com")

    assert_equal "email_1@example.com", user_1.email
    assert_equal "s3krit", user_1.password
    assert_equal "email_2@example.com", user_2.email
    assert_equal "s3kure!", user_2.password
  end

  test "it strips whitespace from CSVs when strip configuration is passed" do
    csv_string = CSV.generate do |csv|
      csv << [" email ", "   password  "]
      csv << ["  email_1@example.com ", " s3krit "]
      csv << [" email_2@example.com ", " s3kure!  "]
    end

    assert_difference("User.count", 2) do
      ArtVandelay::Import.new(:users, strip: true).csv(csv_string)
    end

    user_1 = User.find_by!(email: "email_1@example.com")
    user_2 = User.find_by!(email: "email_2@example.com")

    assert_equal "email_1@example.com", user_1.email
    assert_equal "s3krit", user_1.password
    assert_equal "email_2@example.com", user_2.email
    assert_equal "s3kure!", user_2.password
  end

  test "it strips not-globally-filtered attributes when filtered attributes are passed" do
    author_of_imported_posts =
      User.create!(email: "author@example.com", password: "password")

    csv_string = CSV.generate do |csv|
      csv << %w[title1 content1]
      csv << %w[title2 content2]
    end

    assert_difference("Post.count", 2) do
      ArtVandelay::Import.new(:posts, filtered_attributes: [:title], rollback: true)
        .csv(
          csv_string,
          headers: [:title, :content],
          context: {user: author_of_imported_posts}
        )
    end

    post_1, post_2 = Post.where(user: author_of_imported_posts)

    assert_equal "content1", post_1.content
    assert_equal author_of_imported_posts, post_1.user
    assert_equal "content2", post_2.content
    assert_equal author_of_imported_posts, post_2.user
  end

  test "it strips whitespace from JSON when strip configuration is passed" do
    json_string = [
      {"email": "  email_1@example.com ", "password": " s3krit "},
      {"email": " email_2@example.com ", "password": " s3kure!  "}
    ].to_json

    assert_difference("User.count", 2) do
      ArtVandelay::Import.new(:users, strip: true).json(json_string)
    end

    user_1 = User.find_by!(email: "email_1@example.com")
    user_2 = User.find_by!(email: "email_2@example.com")

    assert_equal "email_1@example.com", user_1.email
    assert_equal "s3krit", user_1.password
    assert_equal "email_2@example.com", user_2.email
    assert_equal "s3kure!", user_2.password
  end

  test "it sets the CSV headers" do
    csv_string = CSV.generate do |csv|
      csv << %w[email_1@example.com s3krit]
      csv << %w[email_2@example.com s3kure!]
    end

    assert_difference("User.count", 2) do
      ArtVandelay::Import.new(:users).csv(csv_string, headers: [:email, :password])
    end

    user_1 = User.find_by!(email: "email_1@example.com")
    user_2 = User.find_by!(email: "email_2@example.com")

    assert_equal "email_1@example.com", user_1.email
    assert_equal "s3krit", user_1.password
    assert_equal "email_2@example.com", user_2.email
    assert_equal "s3kure!", user_2.password
  end

  test "it accepts seeded Active Record attribute values in CSV imports" do
    author_of_imported_posts =
      User.create!(email: "author@example.com", password: "password")

    csv_string = CSV.generate do |csv|
      csv << %w[title1 content1]
      csv << %w[title2 content2]
    end

    assert_difference("Post.count", 2) do
      ArtVandelay::Import.new(:posts, rollback: true)
        .csv(
          csv_string,
          headers: [:title, :content],
          context: {
            content: ->(value) { "#{value} (imported)" },
            user: author_of_imported_posts
          }
        )
    end

    post_1 = Post.find_by!(title: "title1")
    post_2 = Post.find_by!(title: "title2")

    assert_equal "content1 (imported)", post_1.content
    assert_equal author_of_imported_posts, post_1.user
    assert_equal "content2 (imported)", post_2.content
    assert_equal author_of_imported_posts, post_2.user
  end

  test "it accepts seeded Active Record attribute values in JSON imports" do
    author_of_imported_posts =
      User.create!(email: "author@example.com", password: "password")

    json_string = [
      {"title": "title1", "content": "content1"},
      {"title": "title2", "content": "content2"}
    ].to_json

    assert_difference("Post.count", 2) do
      ArtVandelay::Import
        .new(:posts)
        .json(
          json_string,
          context: {
            title: ->(value) { "#{value} (imported)" },
            user: author_of_imported_posts
          }
        )
    end

    post_1 = Post.find_by!(title: "title1 (imported)")
    post_2 = Post.find_by!(title: "title2 (imported)")

    assert_equal "content1", post_1.content
    assert_equal author_of_imported_posts, post_1.user
    assert_equal "content2", post_2.content
    assert_equal author_of_imported_posts, post_2.user
  end

  test "it maps CSV headers to Active Record attributes" do
    csv_string = CSV.generate do |csv|
      csv << %w[email_address passcode]
      csv << %w[email_1@example.com s3krit]
      csv << %w[email_2@example.com s3kure!]
    end

    assert_difference("User.count", 2) do
      ArtVandelay::Import.new(:users).csv(csv_string, attributes: {:email_address => :email, "passcode" => "password"})
    end

    user_1 = User.find_by!(email: "email_1@example.com")
    user_2 = User.find_by!(email: "email_2@example.com")

    assert_equal "email_1@example.com", user_1.email
    assert_equal "s3krit", user_1.password
    assert_equal "email_2@example.com", user_2.email
    assert_equal "s3kure!", user_2.password
  end

  test "it maps JSON keys to Active Record attributes" do
    json_string = [
      {"email_address": "email_1@example.com", "passcode": "s3krit"},
      {"email_address": "email_2@example.com", "passcode": "s3kure!"}
    ].to_json

    assert_difference("User.count", 2) do
      ArtVandelay::Import
        .new(:users)
        .json(
          json_string,
          attributes: {:email_address => :email, "passcode" => "password"}
        )
    end

    user_1 = User.find_by!(email: "email_1@example.com")
    user_2 = User.find_by!(email: "email_2@example.com")

    assert_equal "email_1@example.com", user_1.email
    assert_equal "s3krit", user_1.password
    assert_equal "email_2@example.com", user_2.email
    assert_equal "s3kure!", user_2.password
  end

  test "strips whitespace from CSVs if strip configuration is passed when using custom attributes" do
    csv_string = CSV.generate do |csv|
      csv << ["email_address ", "  passcode "]
      csv << ["  email_1@example.com ", " s3krit "]
      csv << [" email_2@example.com", "   s3kure!  "]
    end

    assert_difference("User.count", 2) do
      ArtVandelay::Import
        .new(:users, strip: true)
        .csv(csv_string, attributes: {:email_address => :email, "passcode" => "password"})
    end

    user_1 = User.find_by!(email: "email_1@example.com")
    user_2 = User.find_by!(email: "email_2@example.com")

    assert_equal "email_1@example.com", user_1.email
    assert_equal "s3krit", user_1.password
    assert_equal "email_2@example.com", user_2.email
    assert_equal "s3kure!", user_2.password
  end

  test "strips whitespace from JSON if the strip configuration is passed when using custom attributes" do
    json_string = [
      {"email_address": "  email_1@example.com ", "passcode": " s3krit "},
      {"email_address": " email_2@example.com", "passcode": "   s3kure!  "}
    ].to_json

    assert_difference("User.count", 2) do
      ArtVandelay::Import
        .new(:users, strip: true)
        .json(
          json_string,
          attributes: {:email_address => :email, "passcode" => "password"}
        )
    end

    user_1 = User.find_by!(email: "email_1@example.com")
    user_2 = User.find_by!(email: "email_2@example.com")

    assert_equal "email_1@example.com", user_1.email
    assert_equal "s3krit", user_1.password
    assert_equal "email_2@example.com", user_2.email
    assert_equal "s3kure!", user_2.password
  end

  test "it no-ops if one record fails to save and 'rollback' is enabled" do
    csv_string = CSV.generate do |csv|
      csv << %w[email password]
      csv << %w[valid@example.com s3kure!]
      csv << %w[invalid@example.com]
      csv << %w[valid@example.com s3kure!]
    end

    json_string = [
      {email: "valid@example.com", password: "s3kure!"},
      {email: "invalid@example.com"},
      {email: "invalid2@example.com", password: nil}
    ].to_json

    assert_no_difference("User.count") do
      assert_raises ActiveRecord::RecordInvalid do
        ArtVandelay::Import.new(:users, rollback: true).csv(csv_string)
      end
    end

    assert_no_difference("User.count") do
      assert_raises ActiveRecord::RecordInvalid do
        ArtVandelay::Import.new(:users, rollback: true).json(json_string)
      end
    end
  end

  test "it saves other records if another fails to save" do
    csv_string = CSV.generate do |csv|
      csv << %w[email password]
      csv << %w[valid_1@example.com s3kure!]
      csv << %w[invalid@example.com]
      csv << %w[valid_2@example.com s3kure!]
    end

    assert_difference("User.count", 2) do
      ArtVandelay::Import.new(:users).csv(csv_string)
    end

    json_string = [
      {email: "valid_3@example.com", password: "s3kure!"},
      {email: "invalid@example.com"},
      {email: "invalid2@example.com", password: nil}
    ].to_json

    assert_difference("User.count", 1) do
      ArtVandelay::Import.new(:users).json(json_string)
    end
  end

  test "returns results" do
    csv_string = CSV.generate do |csv|
      csv << %w[email password]
      csv << %w[valid_1@example.com s3krit]
      csv << %w[invalid@example.com]
      csv << %w[valid_2@example.com s3krit]
    end

    csv_result = ArtVandelay::Import.new(:users).csv(csv_string)

    assert_equal(
      [
        {
          row: ["valid_1@example.com", "s3krit"],
          id: User.find_by!(email: "valid_1@example.com").id
        },
        {
          row: ["valid_2@example.com", "s3krit"],
          id: User.find_by!(email: "valid_2@example.com").id
        }
      ],
      csv_result.rows_accepted
    )
    assert_equal(
      [
        row: ["invalid@example.com", nil],
        errors: {password: [I18n.t("errors.messages.blank")]}
      ],
      csv_result.rows_rejected
    )

    json_string = [
      {email: "valid_3@example.com", password: "s3kure!"},
      {email: "invalid@example.com"},
      {email: "invalid2@example.com", password: nil}
    ].to_json

    json_result = ArtVandelay::Import.new(:users).json(json_string)

    assert_equal(
      [
        {
          row: {"email" => "valid_3@example.com", "password" => "s3kure!"},
          id: User.find_by!(email: "valid_3@example.com").id
        }
      ],
      json_result.rows_accepted
    )

    assert_equal(
      [
        {
          row: {"email" => "invalid@example.com"},
          errors: {password: [I18n.t("errors.messages.blank")]}
        },
        {
          row: {"email" => "invalid2@example.com", "password" => nil},
          errors: {password: [I18n.t("errors.messages.blank")]}
        }
      ],
      json_result.rows_rejected
    )
  end

  test "it returns results when rollback is enabled" do
    csv_string = CSV.generate do |csv|
      csv << %w[email password]
      csv << %w[valid_1@example.com s3krit]
      csv << %w[valid_2@example.com s3krit]
    end

    csv_result = ArtVandelay::Import.new(:users, rollback: true).csv(csv_string)

    assert_equal(
      [
        {
          row: ["valid_1@example.com", "s3krit"],
          id: User.find_by!(email: "valid_1@example.com").id
        },
        {
          row: ["valid_2@example.com", "s3krit"],
          id: User.find_by!(email: "valid_2@example.com").id
        }
      ],
      csv_result.rows_accepted
    )
    assert_empty csv_result.rows_rejected

    json_string = [
      {email: "valid_3@example.com", password: "s3kure!"}
    ].to_json

    json_result =
      ArtVandelay::Import.new(:users, rollback: true).json(json_string)

    assert_equal(
      [
        {
          row: {"email" => "valid_3@example.com", "password" => "s3kure!"},
          id: User.find_by!(email: "valid_3@example.com").id
        }
      ],
      json_result.rows_accepted
    )
    assert_empty json_result.rows_rejected
  end

  test "it updates existing records" do
    # TODO: This requires more thought. We need a way to identify the
    # record(s) and declare we want to update them. This seems like it could
    # be a responsibility of a different class?
    skip
  end
end
