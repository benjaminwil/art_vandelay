require "csv"

class ArtVandelay::Export
  class Result
    attr_reader :exports

    def initialize(exports)
      @exports = exports
    end
  end

  # TODO attributes: self.filtered_attributes
  def initialize(records, export_sensitive_data: false, attributes: [], in_batches_of: ArtVandelay.in_batches_of)
    @records = records
    @export_sensitive_data = export_sensitive_data
    @attributes = attributes
    @in_batches_of = in_batches_of
  end

  def csv
    csv_exports = []

    if records.is_a?(ActiveRecord::Relation)
      records.in_batches(of: in_batches_of) do |relation|
        csv_exports << CSV.parse(generate_csv(relation), headers: true)
      end
    elsif records.is_a?(ActiveRecord::Base)
      csv_exports << CSV.parse(generate_csv(records), headers: true)
    end

    Result.new(csv_exports)
  end

  def json
    json_exports = []

    if records.is_a?(ActiveRecord::Relation)
      records.in_batches(of: in_batches_of) do |relation|
        json_exports << relation
          .map { |record| row(record.attributes, format: :hash) }
          .to_json
      end
    elsif records.is_a?(ActiveRecord::Base)
      json_exports << [row(records.attributes, format: :hash)].to_json
    end

    Result.new(json_exports)
  end

  def email(
    to:,
    from: ArtVandelay.from_address,
    subject: "#{model_name} export",
    body: "#{model_name} export",
    format: :csv
  )
    if from.nil?
      raise ArtVandelay::Error, "missing keyword: :from. Alternatively, set a value on ArtVandelay.from_address"
    end

    mailer = ActionMailer::Base.mail(to: to, from: from, subject: subject, body: body)
    exports = public_send(format).exports

    exports.each.with_index(1) do |export, index|
      if exports.one?
        mailer.attachments[file_name(format: format)] = export
      else
        file = file_name(suffix: "-#{index}", format: format)
        mailer.attachments[file] = export
      end
    end

    mailer.deliver
  end

  private

  attr_reader :records, :export_sensitive_data, :attributes, :in_batches_of

  def file_name(**options)
    options = options.symbolize_keys
    format = options[:format]
    suffix = options[:suffix]
    prefix = model_name.downcase
    timestamp = Time.current.in_time_zone("UTC").strftime("%Y-%m-%d-%H-%M-%S-UTC")

    "#{prefix}-export-#{timestamp}#{suffix}.#{format}"
  end

  def filtered_values(attributes, format:)
    attributes =
      if export_sensitive_data
        ActiveSupport::ParameterFilter.new([]).filter(attributes)
      else
        ActiveSupport::ParameterFilter.new(ArtVandelay.filtered_attributes).filter(attributes)
      end

    case format
    when :hash then attributes
    when :array then attributes.values
    end
  end

  def generate_csv(relation)
    CSV.generate do |csv|
      csv << header
      if relation.is_a?(ActiveRecord::Relation)
        relation.each do |record|
          csv << row(record.attributes)
        end
      elsif relation.is_a?(ActiveRecord::Base)
        csv << row(records.attributes)
      end
    end
  end

  def header
    if attributes.any?
      model.attribute_names.select do |column_name|
        standardized_attributes.include?(column_name)
      end
    else
      model.attribute_names
    end
  end

  def model
    model_name.constantize
  end

  def model_name
    records.model_name.name
  end

  def row(attributes, format: :array)
    if self.attributes.any?
      filtered_values(attributes.slice(*standardized_attributes), format: format)
    else
      filtered_values(attributes, format: format)
    end
  end

  def standardized_attributes
    attributes.map(&:to_s)
  end
end
