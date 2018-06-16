require "sinatra/base"
require "sinatra/namespace"
require "rack/flash"
require "slim"
require "premailer"
require "ipaddr"

require_relative "./models"

module SupplierQuotations
  class Web < Sinatra::Base
    include Models

    register Sinatra::Namespace

    enable :sessions
    use Rack::Flash

    set :root, File.expand_path(File.dirname(__FILE__) + "/../../")

    set :slim,
      :format => :html5,
      :pretty => !settings.production?

    helpers do
      def document_links document
        slug = Document.index_from_document(document).join('-')
        slug += "-#{document.fetch('file_no')}"
        return '_links' => {
          'self' => url("#{@base_url}/document/#{slug}")
        }
      end

      def fetch_populated_rfq rfq_no, revision
        Rfq.fetch(rfq_no, revision) {|rfq|
          lines = Rfq::Line.all_on(rfq) {|line|
            links = {
              'approval' => Rfq::Line.ifs_approval_url(line)
            }

            documents = Document.attached_to(rfq, line) {|doc|
              doc.merge document_links(doc)
            }

            line.merge 'documents' => documents, '_links' => links
          }

          rfq.merge 'lines' => lines,
            'documents' => Document.attached_to(rfq) {|doc|
              doc.merge document_links(doc)
            },
            '_links' => {
              'solicitations' => url("#{@base_url}/solicitations"),
              'responses' => url("#{@base_url}/responses"),
              'ifs' => Rfq.ifs_url(rfq)
            }
        }
      end

      def email template, *args
        html = slim template, *args
        email = Premailer.new html, :with_html_string => true
        return email.to_inline_css
      end

      def table_attrs overrides={}
        container = overrides.delete :container
        {
          :width => container ? '600' : '100%',
          :height => '100%',
          :border => 0,
          :cellpadding => 0,
          :cellspacing => 0
        }.merge overrides
      end

      def rfq_line_default_opts
        {
          :quote => :no_quote,
          :readonly => false,
          :changes => :no_changes,
          :show_additions => true
        }
      end

      def rfq_line line, opt={}
        opt = rfq_line_default_opts.merge opt
        rowspan = 1

        if opt[:changes] != :no_changes
          line = line.merge 'changes' => opt[:changes]
        else
          line = line.merge 'changes' => {}
        end

        if opt[:quote] != :no_quote
          rowspan = 5
          line = line.merge 'quote' => opt[:quote]
        end

        slim :_rfq_line, {}, {
          :line => line,
          :rowspan => rowspan,
          :readonly => opt[:readonly],
          :show_additions => opt[:show_additions]
        }
      end

      def rfq_line_table lines, changes=false, quotes=false, opts={}
        if quotes
          quotes = quotes.inject({}) {|h,q| h[q.fetch('line_no')] = q; h}
        end

        table_lines = lines.collect {|n,l|
          line_opts = opts.dup

          [[:changes, changes], [:quote, quotes]].each do |k,c|
            if c
              v = c.fetch n, :no_entry
              line_opts[k] = v unless v == :no_entry
            end
          end

          [l, line_opts]
        }

        slim :_rfq_line_table, {}, :lines => table_lines
      end

      def rfq_changed_line_table lines, changes
        changed_lines = changes.keys.collect {|n|
          [n, lines.fetch(n)]
        }

        rfq_line_table changed_lines, changes
      end

      def quote_currency selected, editable=false, currencies=@currencies, &block
        locals = {
          :selected => selected,
          :currencies => currencies,
          :readonly => !editable
        }

        slim :_quote_currency, {}, locals, &block
      end

      def ordinal n
        return unless n && n != 0

        if (11..13).include?(n.to_i % 100)
          "th"
        else
          mod_ten = n.to_i % 10

          if mod_ten == 1
            "st"
          elsif mod_ten == 2
            "nd"
          elsif mod_ten == 3
            "rd"
          else
            "th"
          end
        end
      end

      def long_date date
        return date unless date.respond_to? :strftime
        date.strftime("%a %-d<small>#{ordinal date.day}</small> %b '%y")
      end

      def short_date date
        return date unless date.respond_to? :strftime
        date.strftime("%-d<small>#{ordinal date.day}</small> %b '%y")
      end

      def dmy_date date
        return date unless date.respond_to? :strftime
        date.strftime("%d/%m/%y")
      end

      def iso_date date
        return date unless date.respond_to? :strftime
        date.strftime("%Y-%m-%d")
      end

      def nice_number n
        return "-" unless n && n != 0

        if (n - n.floor) > 0.0
          v = sprintf("%.2f", n)
        else
          v = n.to_i.to_s
        end

        return v.gsub(/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
      end

      def mailto_latest_revision rfq, supplier
        "mailto:#{rfq['buyer_email']}?" +
        "Subject=Request%20for%20latest%20revision%20of%20" +
        "RFQ%20#{rfq['rfq_no']}" +
        "&Body=Hi%20#{rfq['buyer_name'] || rfq['buyer_id']}%2C%0A%0A" +
        "Could%20you%20please%20send%20me%20a%20copy%20of%20the%20" +
        "latest%20revision%20of%20RFQ%20#{rfq['rfq_no']}%3F%0A%0A" +
        "Thanks.%0A%0A#{supplier['supplier']}"
      end
    end

    error Models::NotFound do
      not_found
    end

    set(:request_from_lan) do |value|
      lan_ranges = [
        IPAddr.new('10.0.0.0/8'),
        IPAddr.new('172.16.0.0/12'),
        IPAddr.new('192.168.0.0/16'),
        IPAddr.new('fc00::/7')
      ]

      condition do
        ip = IPAddr.new request.ip
        lan_ranges.any? {|r| r.include? ip} == value
      end
    end

    set(:can_revise_quote) do |value|
      condition do
        Rfq.response_allowed?(@rfq) == value &&
        Quote.can_be_revised?(@quote) == value
      end
    end

    set(:status) do |value|
      condition do
        Rfq.send :"#{value}?", @rfq
      end
    end

    get '/terms' do
      slim :terms
    end

    namespace %r{^/rfq/(\d+)/(\d+)/} do
      before do
        rfq_no, revision = *params['captures'][0,2].collect {|n| n.to_i}
        @base_url = "/rfq/#{rfq_no}/#{revision}"
        @rfq = fetch_populated_rfq rfq_no, revision
        @currencies = Currency.all
      end

      # Summary of supplier details
      get 'solicitations', :request_from_lan => true do
        @suppliers = Solicitation.all_for(@rfq) {|s|
          sid = s['supplier_id']
          s.merge '_links' => {
            'solicitation' => url("#{@base_url}/solicitation/#{sid}"),
            'quotation' => url("#{@base_url}/response/#{sid}")
          }
        }

        slim :solicitations
      end

      get 'solicitation' do
        email :solicitation
      end

      # Copy of request for sending to supplier
      get %r{solicitation/(5\d{4})$} do |_, _, supplier_id|
        @supplier = Solicitation.fetch supplier_id, @rfq
        previous_rev = Solicitation.was_sent_prior_revision? @supplier, @rfq

        @response_url = url("#{@base_url}/response/#{supplier_id}")

        if previous_rev != false
          @previous_rfq = fetch_populated_rfq @rfq.fetch('rfq_no'), previous_rev
          @changes = Rfq.diff @rfq, @previous_rfq, %w{revision _links}
          email :solicitation_update
        else
          email :solicitation
        end
      end

      # Summary of responses
      get 'responses', :request_from_lan => true do
        @quotes = Quote.all_received_for(@rfq) {|quote|
          quote.merge(
            'lines' => Quote::Line.all_on(quote),
            '_links' => {
              'self' => url("#{@base_url}/response/#{quote['supplier_id']}"),
              'ifs'  => Quote.ifs_url(quote)
            }
          )
        }

        email :responses
      end

      namespace %r{response/(5\d{4})} do
        before do
          supplier_id = params['captures'][2]
          @supplier = Solicitation.fetch supplier_id, @rfq
          @quote = Quote.fetch(@supplier, @rfq) {|quote|
            quote.merge 'lines' => Quote::Line.all_on(quote)
          }
          @response_url = url("#{@base_url}/response/#{supplier_id}")
          @updated = flash[:updated]
          @quote_complete = Quote.received? @quote
        end

        # Quote formatted as a confirmation email
        get '/confirmation' do
          email :quote_confirmation
        end

        # Quotation form
        get :can_revise_quote => true do
          slim :quote
        end

        get :status => :superceeded do
          slim :quote_superceeded
        end

        get :status => :expired do
          slim :quote_expired
        end

        get do
          slim :quote_closed
        end

        # Submit new/updated quote
        post :can_revise_quote => false do
          status 202
          slim :quote_closed
        end

        post :can_revise_quote => true do
          @original_quote = @quote

          if request.POST['decline'].to_s.downcase == 'all'
            @quote = Quote.decline @quote
          else
            @quote = Quote.update_from_web @quote, request.POST
          end

          @quote = Quote.save @quote

          if Quote.has_errors? @quote
            @error = true
            status 400
            slim :quote
          else
            flash[:updated] = true
            redirect request.path, 303
          end
        end
      end

      # Reject notice for a line to a supplier
      get %r{(\d+)/rejection/(5\d{4})$} do |_, _, line_no, supplier_id|
        line_no = line_no.to_i

        @supplier = Solicitation.fetch supplier_id, @rfq
        @quote = Quote.fetch @supplier, @rfq
        @line = Quote::Line.fetch @quote, line_no

        not_found unless Quote::Line.rejected? @line

        @rfq_line = Rfq.line @rfq, line_no

        email :rejection
      end

      # Copy of an attached document
      get %r{document/(\d{3})\-(\d{7,})\-(\d+)\-([A-Z0-9]+)\-(\d+)$} do
        keys = %w{doc_class_no doc_no sheet revision file_no}
        document = keys.zip(params['captures'][2,keys.size]).inject({}) {|h,kv|
          h[kv[0]] = kv[1]
          h
        }

        not_found unless Document.appears_on? @rfq, document

        @document = Document.fetch document
        @data = Document.data(@document)

        attachment @document.fetch('file_name')
        content_type @document.fetch('file_type'),
          :default => "application/octet-stream"
        response.write @data
      end
    end
  end
end

