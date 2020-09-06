require_relative '../core_ext/numeric'
require_relative '../core_ext/string'


class BatchKit

    module Helpers

        # Defines a number of methods to help with generating simple HTML documents
        module Html

            # Creates a new HTML document with a pre-defined set of styles
            def create_html_document(body_text = nil, opts = {})
                if body_text.is_a?(Hash)
                    opts = body_text
                    body_text = nil
                end

                hdr = <<-EOS.gsub(/^ {20}/, '')
                    <html>
                    #{create_head_tag(opts)}
                    <body>
                EOS
                body = [hdr]
                body << body_text if body_text
                yield body if block_given?
                body << <<-EOS.gsub(/^ {20}/, '')
                    </body>
                    </html>
                EOS
            end


            def create_head_tag(opts = {})
                head_tag = <<-EOS.gsub(/^ {20}/, '')
                    <head>
                    <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=us-ascii">
                    #{opts[:title] ? "<title>#{opts[:title]}</title>" : ''}
                    #{create_style_tag(opts)}
                    </head>
                EOS
            end


            def create_style_tag(opts = {})
                font = opts.fetch(:font, 'Calibri')
                style_tag = <<-EOS.gsub{/^ {20}/, ''}
                    <style>
                        @font-face {font-family: #{font};}

                        h1              {font-family: #{font}; font-size: 16pt; margin: 2em 0em .2em;}
                        h2              {font-family: #{font}; font-size: 14pt; margin: 1em 0em .2em;}
                        h3              {font-family: #{font}; font-size: 12pt; margin: 1em 0em .2em;}
                        body            {font-family: #{font}; font-size: 11pt;}
                        p               {margin: .2em 0em;}
                        table           {font-family: #{font}; font-size: 10pt;
                                         line-height: 12pt; border-collapse: collapse;}
                        th              {background-color: #00205B; color: white;
                                         font-size: 11pt; font-weight: bold; text-align: left;
                                         border: 1px solid #DDDDFF; padding: 1px 5px;}
                        tfoot th        {background-color: #DDDDFF; color: black;
                                         font-size: 10pt; font-weight: normal; text-align: left;
                                         border: 1px solid #DDDDFF; padding: 1px 5px;}
                        td              {border: 1px solid #DDDDFF; padding: 1px 5px;}

                        .summary        {font-size: 13pt;}
                        .black          {background-color: white: color: #000000;}
                        .red            {background-color: white; color: #FF0000;}
                        .amber          {background-color: white; color: #FFA500;}
                        .green          {background-color: white; color: #33A000;}
                        .blue           {background-color: white; color: #0000A0;}
                        .bold           {font-weight: bold;}
                        .center         {text-align: center;}
                        .right          {text-align: right;}
                        .center_red     {text-align: center; background-color: white; color: #FF0000;}
                        .center_amber   {text-align: center; background-color: white; color: #FFA500;}
                        .center_green   {text-align: center; background-color: white; color: #33A000;}
                        .center_blue    {text-align: center; background-color: white; color: #0000A0;}
                        .right_red      {text-align: right; background-color: white; color: #FF0000;}
                        .right_amber    {text-align: right; background-color: white; color: #FFA500;}
                        .right_green    {text-align: right; background-color: white; color: #33A000;}
                        .right_blue     {text-align: right; background-color: white; color: #0000A0;}
                        .separator      {width: 200px; border-bottom: 1px #C0C0C0 solid;}
                        .error          {padding: 5px; color: #FF0000; background-color: #F4F5F7;}
                    </style>
                EOS
            end


            # Creates an HTML table from +data+.
            #
            # @param body [Array] The HTML body to which this table will be
            #   appended.
            # @param data [Array|Hash] The data to be added to the table.
            # @param cols [Array<Symbol|String|Hash>] An array of symbols,
            #   strings, or Hashes. String and symbols output as-is, while the
            #   hash can contain various options that control the display of
            #   the column and the content below it, as follows:
            #     - :name is the name of the property. It will be used to access
            #       data values if +data+ is a Hash, and will be used as the
            #       column header unless a :label property is passed.
            #     - :label is the label to use as the column header.
            #     - :class specifies a CSS class name to assign to each cell in
            #       the column.
            #     - :show is a boolean that determines whether the column is
            #       output or suppressed.
            #     - :prefix is any text that should appear before the content.
            #     - :suffix is any text that should appear after the content.
            def create_html_table(body, data, *cols)
                if cols.last.is_a?(Hash) && cols.last.has_key?(:footer)
                    opts = cols.pop
                else
                    opts = {}
                end
                cols.map!{ |col| col.is_a?(Symbol) || col.is_a?(String) ? {name: col.intern} : col }
                body << "<table>"
                body << "<thead><tr>"
                add_table_cells(body,
                                cols.map{ |col| (col[:label] || col[:name]).to_s.titleize },
                                cols.map{ |col| {show: col.fetch(:show, true)} },
                                :th)
                body << "</tr></thead>"
                body << "<tbody>"
                data.each do |row|
                    body << "<tr>"
                    add_table_cells(body, row, cols)
                    body << "</tr>"
                end
                body << "</tbody>"
                if opts[:footer]
                    body << "<tfoot><tr>"
                    add_table_cells(body, opts[:footer], cols, :th)
                    body << "</tr></tfoot>"
                end
                body << "</table>"
            end


            # Adds a row of cells to a table.
            #
            # @param body [Array<String>] An array of lines containing the body
            #   of the HTML message to which this table row should be added.
            # @param row [Array, Hash, Object] An Array, Hash, or Object from
            #   which a row of data shall be retrieved to populate the table.
            # @param cols [Array<Hash>] An Array of Hashes, each containing
            #   details for a single column. Each Hash can contain the following
            #   options:
            #     - :class: The CSS class with which to style the column cells,
            #       or a lambda that will return a class when called with the
            #       cell value.
            #     - :show: A boolean value indicating whether the column should
            #       be displayed or skipped.
            #     - :prefix: Text to appear before the content of the cell.
            #     - :suffix: Text to appear after the content of the cell.
            #     - :value: A setting controlling how values are retrieved from
            #       +row+. By default, this is by index, but this setting can
            #       override that, and either supply a name or method to call
            #       on +row+, or a Proc object to invoke on row.
            # @param cell_type [Symbol] Either :td (the default) or :th.
            def add_table_cells(body, row, cols, cell_type = :td)
                cols.each_with_index do |col, i|
                    attrs = ''
                    cls = col[:class]
                    show = col.fetch(:show, true)
                    prefix = col.fetch(:prefix, '')
                    suffix = col.fetch(:suffix, '')
                    span_col = col[:span_count]
                    span_idx = col[:span_index]

                    if span_col && span_idx && len(row) > span_idx
                        if row[span_idx] == 1
                            attrs += " rowspan='#{row[span_col]}'"
                        else
                            next
                        end
                    end
                    
                    next if !show

                    val = case
                    when col[:value]
                        col[:value].call(row)
                    when row.is_a?(Array)
                        row[i]
                    when row.is_a?(Hash)
                        row[col[:name]]
                    when row.respond_to?(col[:name])
                        row.send(col[:name])
                    when row.respond_to?(:[])
                        row[col[:name]]
                    else
                        row
                    end

                    if cls.is_a?(Proc)
                        cls = cls.call(val) rescue nil
                    end

                    case val
                    when Numeric
                        val = val.with_commas
                        cls = 'right' unless cls
                    when Date, Time, DateTime
                        val = val.strftime('%H:%M:%S')
                        cls = 'right' unless cls
                    end

                    attrs += " class='#{cls}'" if cls

                    cell = %Q{<#{cell_type}#{attrs}>#{prefix}#{val}#{suffix}</#{cell_type}>}
                    body << cell
                end
            end

        end

    end

end
