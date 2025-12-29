module LogsHelper
  # Optimized: Use client-side rendering for interactive JSON
  # This dramatically reduces server-side rendering time by passing JSON data
  # to a Stimulus controller that handles the interactive display
  def interactive_json(data, prefix = "data")
    return "" if data.blank?

    # Pass data as JSON to be rendered client-side by Stimulus controller
    content_tag(:div,
      "",
      class: "interactive-json text-[12px] font-mono leading-relaxed",
      data: {
        controller: "json-tree",
        json_tree_data_value: data.to_json,
        json_tree_prefix_value: prefix
      }
    )
  end

  # Cached log row cache key
  def log_cache_key(log)
    # LogEntry is immutable, so we can cache based on id + timestamp
    "log_row/v3/#{log.id}/#{log.timestamp.to_i}"
  end

  # Pre-computed filter button for log metadata
  def log_filter_button(label:, value:, query_prefix:, title: nil)
    return nil if value.blank?

    content_tag(:button,
      "#{label}: #{value}",
      data: { action: "click->query#filter", query: "#{query_prefix}:#{value}" },
      class: "hover:underline cursor-pointer",
      style: "color: #1D4ED8;",
      title: title || "Filter by this #{label.downcase}")
  end

  # SVG icon helper to reduce inline SVG duplication
  def log_icon(name)
    icons = {
      session: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>',
      request: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>'
    }
    icons[name]&.html_safe
  end
end
