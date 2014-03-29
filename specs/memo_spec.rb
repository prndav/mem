require_relative '../memo'

describe Memorizable do
  class Mein
    include Memorizable
    remembers :name
    attr_accessor :name

    def initialize name
      @name = name
    end
  end

  let(:mein) { Mein.new('Alba') }

  describe Memorizable::Methods do
    describe '#initialize' do
      it 'calls original initialize method of object' do
        expect(mein.instance_variables).to include(:@name)
      end

      it 'sets class instance variable with saved options and arguments' do
        expect(Mein.instance_variables).to include(:@memo_args)
      end

      it 'initializes memo object' do
        expect(mein.instance_variables).to include(:@memo)
        expect(mein.instance_variable_get(:@memo)).to be_kind_of Memorizable::Memo
      end
    end
  end

  describe Memorizable::Memo do
    let(:memo) { Memorizable::Memo.new([:name],{}, mein)}

    describe '#init_enums' do
      it 'initializes hash where keys are names of specified object instance variables' do
        expect(memo.instance_variable_get(:@e).keys).to eq([:name])
      end

      it 'initializes hash where values are enumerables' do
        expect(memo.instance_variable_get(:@e).first).to be_kind_of Enumerable
      end

      describe 'enumerable levels' do
        let!(:enum) { memo.instance_variable_get(:@e).first.last }

        before do
          enum.rewind
        end

        after do
          enum.rewind
        end

        it 'sets appropriate names for enums' do
          2.times do |n|
            expect(enum.next).to eq("level_#{n+1}")
          end
        end
      end
    end

    describe '#init_hash' do
      it 'initializes hash for tracking vars changes' do
        expect(memo.instance_variable_get(:@h)).to be_kind_of Hash
      end

      it 'sets appropriate keys for initialized hash' do
        expect(memo.instance_variable_get(:@h).keys).to eq([:name])
      end

      it 'inits sub-hash for each passed in symbol(method)' do
        expect(memo.instance_variable_get(:@h)[:name]).to be_kind_of Hash
      end

      context 'with default depth level' do
        it 'inits sub-hash with default depth level' do
          sub_hash = memo.instance_variable_get(:@h)[:name]
          expect(sub_hash.keys.count).to eq(2)
        end
      end

      context 'with specified depth level' do
        let(:memo) { Memorizable::Memo.new([:name],{level: 5}, mein)}

        it 'inits sub-hash with specified depth level' do
          sub_hash = memo.instance_variable_get(:@h)[:name]
          expect(sub_hash.keys.count).to eq(5)
        end
      end

      it 'sets initial values for object variables' do
        expect(memo.instance_variable_get(:@h)[:name]['level_1']).to eq('Alba')
      end

      it 'moves pointer after setting initial value of object variable' do
        expect(memo.instance_variable_get(:@e)[:name].next).to eq('level_2')
      end
    end

    describe '#set_current_value' do
      it 'sets current value for object instance var' do
        memo.send(:set_current_value, :name, 'Funky')
        expect(memo.instance_variable_get(:@h)[:name]['level_2']).to eq('Funky')
      end

      context 'when maximum level reached' do
        it 'rewinds enum and sets current value for object instance var' do
          memo.instance_variable_get(:@e)[:name].next
          memo.send(:set_current_value, :name, 'Junky')
          expect(memo.instance_variable_get(:@h)[:name]['level_1']).to eq('Junky')
        end
      end

      describe '#get_current_pointer' do
        it 'returns current pointer' do
          expect(memo.send(:get_current_pointer, :name)).to eq(1)
          memo.instance_variable_get(:@e)[:name].next
          expect(memo.send(:get_current_pointer, :name)).to eq(2)
        end
      end
    end

    describe '#chageset' do
      it 'returns current and previous values for passed in key' do
        memo.send(:set_current_value, :name, 'Junky')
        expect(memo.send(:changeset, :name)).to eq(['Junky', 'Alba'])
      end
    end

    describe '#prev_values' do
      it 'previous values for passed in key' do
        memo.send(:set_current_value, :name, 'Junky')
        expect(memo.send(:prev_values, :name)).to eq('Alba')
      end
    end

    describe '#get_prev_value' do
      it 'returns nil if there is no previous value' do
        expect(memo.send(:get_prev_value, :name)).to eq(nil)
      end

      it 'returns previous value for specified key' do
        memo.send(:set_current_value, :name, 'Junky')
        expect(memo.send(:get_prev_value, :name)).to eq('Alba')
      end

      context 'when pointer specified' do
        it 'returns previous value for specified key' do
          memo.send(:set_current_value, :name, 'Junky')
          expect(memo.send(:get_prev_value, :name, 2)).to eq('Alba')
        end
      end
    end


    describe '#get_prev_values_set' do
      let(:memo) { Memorizable::Memo.new([:name],{level: 5}, mein)}

      it 'returns false if specified count is greater then hash level' do
        memo.send(:set_current_value, :name, 'Junky')
        expect(memo.send(:get_prev_values_set, :name, 5)).to eq(false)
      end

      it 'returns set of previous values for specified key' do
        arr = []
        4.times do |n|
          arr << memo.send(:set_current_value, :name, "Alba_#{n+1}")
        end
        memo.send(:set_current_value, :name, 'Junky')
        expect(memo.send(:get_prev_values_set, :name, 4)).to eq(arr.reverse)
      end

    end

    describe '#get_current_value' do
      it 'returns current value for specified key' do
        expect(memo.send(:get_current_value, :name)).to eq('Alba')
      end
    end
  end

  describe 'helper methods' do
    describe 'previous_...' do
      it 'returns previous value of object instance variable' do
        mein.name = 'Crazy'
        expect(mein.prev_name).to eq('Alba')
        mein.name = 'Bender'
        expect(mein.prev_name).to eq('Crazy')
        mein.name = 'Kenny'
        expect(mein.prev_name).to eq('Bender')
      end

      context 'when count is specified' do
        before do
          Mein.class_eval do
            remembers :name, level: 5
          end
        end

        it 'returns set of previous values' do
          mein = Mein.new('Alba')
          2.times do |n|
            mein.name = "Alba_#{n+1}"
          end
          expect(mein.prev_name(2)).to eq(['Alba_1', 'Alba'])
        end
      end
    end

    describe '..._changed?' do

      it 'returns true if current value does not equal previous' do
        mein.name = 'J'
        expect(mein.name_changed?).to be_truthy
        mein.name = nil
        expect(mein.name_changed?).to be_truthy
      end

      it 'returns false if current value equals previous' do
        mein.name = 'Alba'
        expect(mein.name_changed?).to be_falsy
      end
    end
  end
end
