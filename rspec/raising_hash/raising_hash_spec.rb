require 'raising_hash'

describe 'RaisingHash' do

  let(:raising_hash) { RaisingHash.new }

  describe '#[]' do
    it 'returns nil to any key' do
      expect(raising_hash[:any]).to be_nil
    end
  end

  describe '#[]=' do
    it 'returns a given value' do
      expect( raising_hash[:key] = :value ).to eq :value
    end

    it 'assigns a given value' do
      expect { raising_hash[:key] = :value }.to change { raising_hash[:key] }.from(nil).to(:value)
    end
  end

  describe '#empty?' do
    subject { raising_hash.empty? }

    context 'empty' do
      it 'returns true' do
        is_expected.to be_truthy
      end
    end

    context 'not empty' do
      before { raising_hash[:key] = :value }

      it 'returns false' do
        is_expected.to be_falsey
      end
    end
  end

  describe '#has_key?' do
    before { raising_hash[:key] = :value }

    it 'returns false if the given key does not exist' do
      expect(raising_hash.has_key?(:key_no)).to be_falsey
    end

    it 'returns false if the given key exists' do
      expect(raising_hash.has_key?(:key)).to be_truthy
    end
  end

  describe '#size' do
    subject { raising_hash.size }

    context 'empty' do
      it 'returns 0' do
        is_expected.to be 0
      end
    end

    context 'not empty (three entries)' do
      before do
        raising_hash[:key1] = :value1
        raising_hash[:key2] = :value2
        raising_hash[:key3] = :value3
      end

      it 'returns 3' do
        is_expected.to be 3
      end
    end
  end

  describe '#delete' do
    context 'empty' do
      it 'returns nil' do
        expect(raising_hash.delete(:key)).to be_nil
      end

      it 'does not change the receiver' do
        expect { raising_hash.delete(:key) }.not_to change { raising_hash.size }
      end
    end

    context 'not empty (three entries)' do
      before do
        raising_hash[:key1] = :value1
        raising_hash[:key2] = :value2
        raising_hash[:key3] = :value3
      end

      context 'the given key does not exist' do
        it 'returns nil' do
          expect(raising_hash.delete(:key_no)).to be_nil
        end

        it 'does not change the receiver' do
          expect { raising_hash.delete(:key_no) }.not_to change { raising_hash.size }
        end
      end

      context 'the given key exists' do
        it 'returns the corresponding value' do
          expect(raising_hash.delete(:key2)).to be :value2
        end

        it 'does not change the receiver' do
          expect { raising_hash.delete(:key2) }.to change { raising_hash.size }.from(3).to(2)
        end
      end
    end
  end

  describe '#keys' do
    subject { raising_hash.keys }

    context 'empty' do
      it 'returns an empty Array' do
        is_expected.to be_empty
      end
    end

    context 'not empty (three entries)' do
      before do
        raising_hash[:key1] = :value1
        raising_hash[:key2] = :value2
        raising_hash[:key3] = :value3
      end

      it 'returns an Array of keys' do
        is_expected.to match_array [:key1, :key2, :key3]
      end
    end
  end

  describe '#values' do
    subject { raising_hash.values }

    context 'empty' do
      it 'returns an empty Array' do
        is_expected.to be_empty
      end
    end

    context 'not empty (three entries)' do
      before do
        raising_hash[:key1] = :value1
        raising_hash[:key2] = :value2
        raising_hash[:key3] = :value3
      end

      it 'returns an Array of values' do
        is_expected.to match_array [:value1, :value2, :value3]
      end
    end
  end

  describe '#each' do
    context 'empty' do
      let(:accumulator) { [] }

      it 'returns an Enumerator when called without an argument' do
        expect(raising_hash.each).to be_a Enumerator
      end

      it 'does nothing when called with a block' do
        expect { raising_hash.each { |k, v| accumulator << [k, v] } }.not_to change { accumulator }
      end
    end

    context 'not empty (three entries)' do
      let(:accumulator) { [] }

      before do
        raising_hash[:key1] = :value1
        raising_hash[:key2] = :value2
        raising_hash[:key3] = :value3
      end

      it 'returns an Enumerator when called without an argument' do
        expect(raising_hash.each).to be_a Enumerator
      end

      it 'browses all entries when called with a block' do
        expect { raising_hash.each { |k, v| accumulator << [k, v] } }.to \
            change { accumulator }.from([]).to(match_array [[:key1, :value1], [:key2, :value2],  [:key3, :value3]]) 
      end
    end
  end
end
