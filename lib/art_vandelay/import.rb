require "csv"

class ArtVandelay::Import
  class Result
    attr_reader :rows_accepted, :rows_rejected

    def initialize(rows_accepted:, rows_rejected:)
      @rows_accepted = rows_accepted
      @rows_rejected = rows_rejected
    end
  end

  def initialize(model_name, **options)
    @options = options.symbolize_keys
    @rollback = options[:rollback]
    @strip = options[:strip]
    @model_name = model_name
  end

  def csv(csv_string, **options)
    options = options.symbolize_keys
    headers = options[:headers] || true
    attributes = options[:attributes] || {}
    context = options[:context] || {}
    rows = build_csv(csv_string, headers)

    if rollback
      # TODO: It would be nice to still return a result object during a
      # failure
      active_record.transaction do
        parse_rows(rows, attributes, context, raise_on_error: true)
      end
    else
      parse_rows(rows, attributes, context)
    end
  end

  def json(json_string, **options)
    options = options.symbolize_keys
    attributes = options[:attributes] || {}
    context = options[:context] || {}
    array = JSON.parse(json_string)

    if rollback
      active_record.transaction do
        parse_json_data(array, attributes, context, raise_on_error: true)
      end
    else
      parse_json_data(array, attributes, context)
    end
  end

  private

  attr_reader :model_name, :rollback, :strip

  def active_record
    model_name.to_s.classify.constantize
  end

  def build_csv(csv_string, headers)
    CSV.parse(csv_string, headers: headers)
  end

  def build_params(row, attributes)
    attributes = attributes.stringify_keys

    if strip
      row.to_h.stringify_keys.transform_keys do |key|
        attributes[key.strip] || key.strip
      end.tap do |new_params|
        new_params.transform_values!(&:strip)
      end
    else
      row.to_h.stringify_keys.transform_keys do |key|
        attributes[key] || key
      end
    end
  end

  def parse_json_data(array, attributes, context, **options)
    raise_on_error = options[:raise_on_error] || false
    result = Result.new(rows_accepted: [], rows_rejected: [])

    array.each do |entry|
      params = build_params(entry, attributes).merge(context)
      record = active_record.new(params)

      if raise_on_error ? record.save! : record.save
        result.rows_accepted << {row: entry, id: record.id}
      else
        result.rows_rejected << {row: entry, errors: record.errors.messages}
      end
    end

    result
  end

  def parse_rows(rows, attributes, context, **options)
    options = options.symbolize_keys
    raise_on_error = options[:raise_on_error] || false
    result = Result.new(rows_accepted: [], rows_rejected: [])

    rows.each do |row|
      params = build_params(row, attributes).merge(context)
      record = active_record.new(params)

      if raise_on_error ? record.save! : record.save
        result.rows_accepted << {row: row.fields, id: record.id}
      else
        result.rows_rejected << {row: row.fields, errors: record.errors.messages}
      end
    end

    result
  end
end
