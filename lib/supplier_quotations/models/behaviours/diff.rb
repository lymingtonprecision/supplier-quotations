module SupplierQuotations; module Models;
  class Diff
    def self.empty_diff
      {'removed' => {}, 'added' => {}, 'modified' => {}, 'same' => {}}
    end

    def self.call new, old, ignored_keys=[], diff=empty_diff
      new_keys = new.keys - ignored_keys
      old_keys = old.keys - ignored_keys

      [
        [diff['removed'], old_keys, new_keys, old],
        [diff['added'],   new_keys, old_keys, new]
      ].collect {|d,l,r,h|
        (l - r).each {|k| d[k] = h.fetch k}
      }

      (old_keys & new_keys).each do |k|
        old_value = old.fetch k
        new_value = new.fetch k

        if old_value.kind_of?(Hash) && new_value.kind_of?(Hash)
          sub_diff = self.call new_value, old_value, ignored_keys

          if %w{removed added modified}.all? {|c| sub_diff[c].empty?}
            diff['same'][k] = new_value
          else
            diff['modified'][k] = sub_diff
          end
        elsif old_value != new_value
          diff['modified'][k] = [old_value, new_value]
        else
          diff['same'][k] = new_value
        end
      end

      return diff
    end
  end
end; end

