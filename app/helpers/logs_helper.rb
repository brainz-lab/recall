module LogsHelper
  def interactive_json(data, prefix = "data")
    return "" if data.blank?

    content_tag(:div, class: "text-[12px] font-mono leading-relaxed") do
      render_json_value(data, prefix, 0)
    end
  end

  private

  def render_json_value(value, path, indent)
    case value
    when Hash
      render_hash(value, path, indent)
    when Array
      render_array(value, path, indent)
    else
      render_primitive(value, path)
    end
  end

  def render_hash(hash, path, indent)
    return content_tag(:span, "{}", style: "color: #6B6760;") if hash.empty?

    lines = []
    lines << content_tag(:span, "{", style: "color: #6B6760;")

    hash.each_with_index do |(key, value), idx|
      child_path = "#{path}.#{key}"
      comma = idx < hash.size - 1 ? "," : ""

      line_content = safe_join([
        content_tag(:span, "\"#{key}\"", style: "color: #1D4ED8;"),
        content_tag(:span, ": ", style: "color: #6B6760;"),
        render_clickable_value(value, child_path, indent + 1),
        content_tag(:span, comma, style: "color: #6B6760;")
      ])

      lines << content_tag(:div, line_content, style: "padding-left: #{(indent + 1) * 12}px;")
    end

    lines << content_tag(:div, "}", style: "color: #6B6760; padding-left: #{indent * 12}px;")
    safe_join(lines)
  end

  def render_array(array, path, indent)
    return content_tag(:span, "[]", style: "color: #6B6760;") if array.empty?

    lines = []
    lines << content_tag(:span, "[", style: "color: #6B6760;")

    array.each_with_index do |value, idx|
      child_path = "#{path}[#{idx}]"
      comma = idx < array.size - 1 ? "," : ""

      line_content = safe_join([
        render_json_value(value, child_path, indent + 1),
        content_tag(:span, comma, style: "color: #6B6760;")
      ])

      lines << content_tag(:div, line_content, style: "padding-left: #{(indent + 1) * 12}px;")
    end

    lines << content_tag(:div, "]", style: "color: #6B6760; padding-left: #{indent * 12}px;")
    safe_join(lines)
  end

  def render_clickable_value(value, path, indent)
    case value
    when Hash
      render_hash(value, path, indent)
    when Array
      render_array(value, path, indent)
    else
      render_primitive(value, path)
    end
  end

  def render_primitive(value, path)
    display = value.is_a?(String) ? "\"#{h(value)}\"" : value.to_s
    # Wrap value in quotes if it contains spaces or special characters
    escaped_value = if value.is_a?(String) && value.match?(/[\s:"|]/)
      "\"#{value.gsub('"', '\\"')}\""
    else
      value.to_s
    end
    query = "#{path}:#{escaped_value}"

    content_tag(:button,
      display.html_safe,
      type: "button",
      data: { action: "click->query#filter", query: query },
      class: "hover:bg-blue-100 px-0.5 rounded cursor-pointer transition-colors",
      style: value.is_a?(String) ? "color: #059669;" : "color: #D97706;",
      title: "Filter: #{query}"
    )
  end
end
