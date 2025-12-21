require 'csv'

class LogExporter
  EXPORT_COLUMNS = %w[id timestamp level message environment service host commit branch session_id request_id data].freeze

  def initialize(project, query: nil, since: nil, until_time: nil, format: :json)
    @project = project
    @query = query
    @since = since
    @until_time = until_time
    @format = format.to_sym
  end

  def export
    case @format
    when :csv
      to_csv
    else
      to_json
    end
  end

  def to_json
    logs.to_json
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << EXPORT_COLUMNS
      logs.find_each do |log|
        csv << [
          log.id,
          log.timestamp.iso8601,
          log.level,
          log.message,
          log.environment,
          log.service,
          log.host,
          log.commit,
          log.branch,
          log.session_id,
          log.request_id,
          log.data.to_json
        ]
      end
    end
  end

  def filename
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    extension = @format == :csv ? 'csv' : 'json'
    "#{@project.name.parameterize}_logs_#{timestamp}.#{extension}"
  end

  def content_type
    @format == :csv ? 'text/csv' : 'application/json'
  end

  def count
    logs.count
  end

  private

  def logs
    @logs ||= build_scope
  end

  def build_scope
    scope = @project.log_entries

    # Apply query parser if query provided
    if @query.present?
      parser = QueryParser.new(@query).parse
      scope = parser.apply(scope)
    end

    # Apply date range filters
    if @since.present?
      since_time = parse_time(@since)
      scope = scope.where('timestamp >= ?', since_time) if since_time
    end

    if @until_time.present?
      until_parsed = parse_time(@until_time)
      scope = scope.where('timestamp <= ?', until_parsed) if until_parsed
    end

    scope.order(timestamp: :desc)
  end

  def parse_time(value)
    return nil if value.blank?

    # Handle relative time like "1h", "24h", "7d"
    if value =~ /^(\d+)([mhdw])$/
      amount = $1.to_i
      unit = { 'm' => :minutes, 'h' => :hours, 'd' => :days, 'w' => :weeks }[$2]
      return amount.send(unit).ago if unit
    end

    # Try parsing as datetime
    Time.parse(value)
  rescue ArgumentError
    nil
  end
end
