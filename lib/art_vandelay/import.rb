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
    @filtered_attributes = options[:filtered_attributes]
    @strip = options[:strip]
    @model_name = model_name
  end

  def csv(csv_string, **options)
    options = options.symbolize_keys
    headers = options[:headers] || true
    attributes = (options[:attributes] || {}).with_indifferent_access
    context = (options[:context] || {}).with_indifferent_access
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
    attributes = (options[:attributes] || {}).with_indifferent_access
    context = (options[:context] || {}).with_indifferent_access
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

  attr_reader :filtered_attributes, :model_name, :rollback, :strip

  def active_record
    model_name.to_s.classify.constantize
  end

  def build_csv(csv_string, headers)
    CSV.parse(csv_string, headers: headers)
  end

  def build_params(row, attributes)
    attributes = attributes.except(*filtered_attributes)
    data = row.to_h.with_indifferent_access.except(*filtered_attributes)

    return data.transform_keys { |key| attributes[key] || key } unless strip

    data.transform_keys { |key| attributes[key.strip] || key.strip }
      .tap { |new_params| new_params.transform_values!(&:strip) }
  end

  def parse_json_data(array, attributes, context, **options)
    raise_on_error = options[:raise_on_error] || false
    result = Result.new(rows_accepted: [], rows_rejected: [])

    array.each do |entry|
      params = build_params(entry, attributes)
      params = params.merge(parse_context_for(params, context))
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
      params = build_params(row, attributes)
      params = params.merge(parse_context_for(params, context))
      record = active_record.new(params)

      if raise_on_error ? record.save! : record.save
        result.rows_accepted << {row: row.fields, id: record.id}
      else
        result.rows_rejected << {row: row.fields, errors: record.errors.messages}
      end
    end

    result
  end

  def parse_context_for(entry, context)
    return context if context.values.none? { _1.is_a? Proc }

    context.to_h { |key, value|
      next [key, value] unless value.is_a?(Proc)

      [key, value.call(entry[key])]
    }
  end
end
