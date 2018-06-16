module SupplierQuotations; module Models;
  module WebInputConvertor
    def web_convertors attr=:all
      @web_convertors ||= {}

      if attr == :all
        @web_convertors
      else
        @web_convertors[attr] ||= []
      end
    end

    def converts_from_web attr, conversion=:block, &block
      conversion = block if conversion == :block && block_given?
      web_convertors(attr) << conversion
      return nil
    end

    def convert_from_web attr, web_input
      converted_value = web_input

      web_convertors(attr).each {|convertor|
        converted_value = convertor.call web_input
      }

      return converted_value
    end

    def converts_from_web_number attr
      converts_from_web attr do |input|
        if input && !input.kind_of?(Numeric)
          input = input.to_s.strip.gsub(/,/, '')

          if input =~ /^\d+(,\d+)*$/
            input = input.to_i
          elsif input =~ /^\d+(,\d+)*\.\d+$/
            input = input.to_f
          elsif input.empty?
            input = nil
          end
        end

        input
      end
    end

    def converts_from_web_date attr
      converts_from_web attr do |input|
        if input && !(input.kind_of?(Date) || input.kind_of?(Time))
          input = input.to_s.strip
          y,m,d = nil

          if input =~ /^(\d{1,2}[\.\-\/]){2}\d{2,4}$/
            d,m,y = input.split(/[\.\-\/]/).collect {|n| n.to_i}
          elsif input =~ /^\d{4}([\.\-\/]\d{1,2}){2}$/
            y,m,d = input.split(/[\.\-\/]/).collect {|n| n.to_i}
          elsif input.empty?
            input = nil
          end

          y += (Date.today.year / 1000) * 1000 if !y.nil? && y < 1000

          if !y.nil?
            begin
              input = Date.new y, m, d
            rescue ArgumentError
            end
          end
        end

        input
      end
    end
  end
end; end

