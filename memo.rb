require 'pry'

module Memorizable
  class Memo
    attr_reader :level, :h

    def initialize meths, opts, obj
      @level = opts[:level] || 2
      @e = init_enums(meths)
      @h = init_hash(meths, obj)
      define_helper_methods(meths, obj)
    end

    private

      def define_helper_methods(meths, obj)
        eigen = class << obj; self; end
        meths.each do |meth|
          eigen.class_eval do

            define_method "prev_#{meth}" do |args=nil|
              @memo.send :prev_values, meth, args
            end

            define_method "#{meth}_changed?" do
              changeset = @memo.send :changeset, meth
              !(changeset[0] == changeset[1])
            end

            define_method "#{meth}_changeset" do
              @memo.send :changeset, meth
            end

          end
        end
      end

      def get_current_pointer(key)
        @e[key].peek[-1].to_i - 1
      rescue StopIteration
        level
      end

      def changeset(key)
        prev = get_prev_value(key)
        current = get_current_value(key)
        [current, prev]
      end

      def get_current_value(key)
        n = get_current_pointer(key)
        h[key]["level_".concat((n).to_s)]
      end

      def prev_values(key, count=nil)
        if count
          get_prev_values_set(key, count)
        else
          get_prev_value(key)
        end
      end

      def get_prev_value(key, pointer=nil)
        i = pointer || get_current_pointer(key)
        pointer = i > 1 ? i - 1 : level
        value = h[key]["level_".concat((pointer).to_s)]
        value.empty? ? nil : value
      end

      def get_prev_values_set(key, count)
        return false if count > level - 1
        i = get_current_pointer(key)
        set = []
        count.times do
          set << get_prev_value(key, i)
          i = i > 1 ? i - 1 : level
        end
        set
      end

      def init_enums(methods)
        arr = 1.upto(level).inject([]) {|mem, n| mem << "level_#{n}"; mem }
        e = methods.inject({}) {|mem, key| mem[key] = arr.to_enum; mem }
      end

      def init_hash(methods, object)
        memo = Hash.new.tap do |h|
          methods.each do |k|
            h[k] = 1.upto(level).inject({}) {|mem, n|  mem["level_#{n}"] = ''; mem }
            pointer = @e[k].next
            h[k][pointer] = object.instance_variable_get("@#{k.to_s}")
          end
        end
        memo
      end

      def set_current_value(key, value)
        pointer = @e[key].next
        @h[key][pointer] = value
      rescue StopIteration
        @e[key].rewind
        set_current_value(key, value)
      end
  end

  module Methods
    def self.prepended(receiver)
      class << receiver
        def remembers *args, **options
          self.instance_variable_set(:@memo_args, [args, options])
        end
      end
    end

    def initialize *args
      super(*args)
      meths, opts = self.class.instance_variable_get(:@memo_args)
      @memo = Memo.new(meths, opts, self)

      eigen = class << self; self; end
      eigen.class_eval do
        meths.each do |meth|
          define_method "#{meth}=" do |val|
            super(val)
            @memo.send :set_current_value, meth, val
          end
        end
      end
    end
  end

  def self.included(receiver)
    receiver.send :prepend, Methods
  end
end
