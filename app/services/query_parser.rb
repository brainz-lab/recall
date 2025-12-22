class QueryParser
  LEVELS = %w[debug info warn error fatal].freeze
  TIME_UNITS = { 'm' => :minutes, 'h' => :hours, 'd' => :days, 'w' => :weeks }.freeze

  def initialize(query_string)
    @query = query_string.to_s.strip
    @filters = {}
    @text_searches = []
    @commands = []
    @or_groups = []  # For OR support
  end

  def parse
    parts = @query.split(/\s*\|\s*(?=(?:[^"]*"[^"]*")*[^"]*$)/)
    filter_part = parts[0] || ""

    # Check for OR operator (case insensitive, with spaces)
    if filter_part =~ /\s+OR\s+/i
      # Split by OR and parse each group
      or_parts = filter_part.split(/\s+OR\s+/i)
      or_parts.each do |or_part|
        group = { filters: {}, text_searches: [] }
        parse_filters_into(or_part.strip, group[:filters], group[:text_searches])
        @or_groups << group
      end
    else
      # No OR, parse normally into default filters
      parse_filters(filter_part)
    end

    (parts[1..] || []).each { |cmd| @commands << parse_command(cmd.strip) }
    self
  end

  def apply(scope)
    if @or_groups.any?
      # Apply OR logic - combine groups with OR
      combined_scope = nil
      @or_groups.each do |group|
        group_scope = apply_filters_from(scope, group[:filters], group[:text_searches])
        combined_scope = combined_scope ? combined_scope.or(group_scope) : group_scope
      end
      scope = combined_scope if combined_scope
    else
      # Normal AND logic
      scope = apply_level(scope)
      scope = apply_environment(scope)
      scope = apply_commit(scope)
      scope = apply_branch(scope)
      scope = apply_service(scope)
      scope = apply_host(scope)
      scope = apply_request_id(scope)
      scope = apply_session_id(scope)
      scope = apply_time_filters(scope)
      scope = apply_data_filters(scope)
      scope = apply_text_search(scope)
    end
    scope = apply_ordering(scope)
    scope
  end

  def stats?
    @commands.any? { |c| c[:command] == 'stats' }
  end

  def apply_stats(scope)
    cmd = @commands.find { |c| c[:command] == 'stats' }
    group_by = cmd&.dig(:args)&.find { |a| a.start_with?('by:') }&.sub('by:', '')

    # Remove default ordering for GROUP BY operations
    scope = scope.unscope(:order)

    case group_by
    when 'level' then scope.group(:level).count
    when 'commit' then scope.group(:commit).count
    when 'environment', 'env' then scope.group(:environment).count
    when 'hour' then scope.group_by_hour(:timestamp).count
    when 'day' then scope.group_by_day(:timestamp).count
    else
      { total: scope.count, by_level: scope.group(:level).count }
    end
  end

  def limit
    cmd = @commands.find { |c| %w[first last].include?(c[:command]) }
    cmd ? (cmd[:args]&.first&.to_i || 100) : 100
  end

  private

  def parse_filters(part)
    parse_filters_into(part, @filters, @text_searches)
  end

  def parse_filters_into(part, filters, text_searches)
    # First extract field:value pairs (including quoted values)
    # Pattern: field.path:value or field.path:"quoted value"
    part.scan(/(\w+(?:\.\w+)*):(!)?("[^"]*"|[^\s]+)/) do |field, neg, value|
      # Remove surrounding quotes if present
      clean_value = value.start_with?('"') && value.end_with?('"') ? value[1..-2] : value
      filters[field] = { value: clean_value, negated: neg == '!' }
    end

    # Then extract standalone quoted text searches (not part of field:value)
    # Remove field:value patterns first, then find remaining quoted strings
    remaining = part.gsub(/\w+(?:\.\w+)*:!?(?:"[^"]*"|[^\s]+)/, '')
    remaining.scan(/"([^"]+)"/) { |m| text_searches << m[0] }
  end

  def apply_filters_from(scope, filters, text_searches)
    # Level filter
    if filters['level']
      f = filters['level']
      levels = f[:value].split(',') & LEVELS
      scope = f[:negated] ? scope.where.not(level: levels) : scope.where(level: levels)
    end

    # Environment filter
    f = filters['env'] || filters['environment']
    if f
      scope = f[:negated] ? scope.where.not(environment: f[:value]) : scope.where(environment: f[:value])
    end

    # Commit filter
    if filters['commit']
      scope = scope.where(commit: filters['commit'][:value])
    end

    # Branch filter
    if filters['branch']
      scope = scope.where(branch: filters['branch'][:value])
    end

    # Service filter
    if filters['service']
      scope = scope.where(service: filters['service'][:value])
    end

    # Host filter
    if filters['host']
      scope = scope.where(host: filters['host'][:value])
    end

    # Request ID filter
    f = filters['request_id'] || filters['request']
    scope = scope.where(request_id: f[:value]) if f

    # Session ID filter
    f = filters['session_id'] || filters['session']
    scope = scope.where(session_id: f[:value]) if f

    # Time filters
    if filters['since']
      scope = scope.where('timestamp >= ?', parse_time(filters['since'][:value]))
    end
    if filters['until']
      scope = scope.where('timestamp <= ?', parse_time(filters['until'][:value]))
    end

    # Data filters (JSONB)
    filters.each do |field, f|
      next unless field.start_with?('data.')
      path = field.sub('data.', '').split('.')
      json_path = "{#{path.join(',')}}"

      if f[:value] =~ /^([><]=?)(.+)$/
        scope = scope.where("CAST(data #>> ? AS NUMERIC) #{$1} ?", json_path, $2.to_f)
      elsif f[:value].include?('*')
        pattern = f[:value].gsub('*', '%')
        scope = scope.where("data #>> ? LIKE ?", json_path, pattern)
      else
        scope = scope.where("data #>> ? = ?", json_path, f[:value])
      end
    end

    # Text searches
    text_searches.each { |t| scope = scope.where("message ILIKE ?", "%#{t}%") }

    scope
  end

  def parse_command(str)
    tokens = str.split(/\s+/)
    { command: tokens[0], args: tokens[1..] }
  end

  def apply_level(scope)
    return scope unless @filters['level']
    f = @filters['level']
    levels = f[:value].split(',') & LEVELS
    f[:negated] ? scope.where.not(level: levels) : scope.where(level: levels)
  end

  def apply_environment(scope)
    f = @filters['env'] || @filters['environment']
    return scope unless f
    f[:negated] ? scope.where.not(environment: f[:value]) : scope.where(environment: f[:value])
  end

  def apply_commit(scope)
    return scope unless @filters['commit']
    scope.where(commit: @filters['commit'][:value])
  end

  def apply_branch(scope)
    return scope unless @filters['branch']
    scope.where(branch: @filters['branch'][:value])
  end

  def apply_service(scope)
    return scope unless @filters['service']
    scope.where(service: @filters['service'][:value])
  end

  def apply_host(scope)
    return scope unless @filters['host']
    scope.where(host: @filters['host'][:value])
  end

  def apply_request_id(scope)
    f = @filters['request_id'] || @filters['request']
    f ? scope.where(request_id: f[:value]) : scope
  end

  def apply_session_id(scope)
    f = @filters['session_id'] || @filters['session']
    f ? scope.where(session_id: f[:value]) : scope
  end

  def apply_time_filters(scope)
    if @filters['since']
      scope = scope.where('timestamp >= ?', parse_time(@filters['since'][:value]))
    end
    if @filters['until']
      scope = scope.where('timestamp <= ?', parse_time(@filters['until'][:value]))
    end
    scope
  end

  def parse_time(value)
    if value =~ /^(\d+)([mhdw])$/
      $1.to_i.send(TIME_UNITS[$2]).ago
    else
      Time.parse(value)
    end
  rescue
    1.hour.ago
  end

  def apply_data_filters(scope)
    @filters.each do |field, f|
      next unless field.start_with?('data.')
      path = field.sub('data.', '').split('.')
      json_path = "{#{path.join(',')}}"

      if f[:value] =~ /^([><]=?)(.+)$/
        # Numeric comparison: data.count:>10
        scope = scope.where("CAST(data #>> ? AS NUMERIC) #{$1} ?", json_path, $2.to_f)
      elsif f[:value].include?('*')
        # Wildcard matching: data.key:user:* becomes LIKE 'user:%'
        pattern = f[:value].gsub('*', '%')
        scope = scope.where("data #>> ? LIKE ?", json_path, pattern)
      else
        # Exact match
        scope = scope.where("data #>> ? = ?", json_path, f[:value])
      end
    end
    scope
  end

  def apply_text_search(scope)
    @text_searches.each { |t| scope = scope.where("message ILIKE ?", "%#{t}%") }
    scope
  end

  def apply_ordering(scope)
    if @commands.any? { |c| c[:command] == 'first' }
      scope.reorder(timestamp: :asc)
    else
      scope.reorder(timestamp: :desc)
    end
  end
end
