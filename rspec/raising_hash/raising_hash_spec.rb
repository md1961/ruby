require 'raising_hash'

describe 'RaisingHash' do

  let(:raising_hash) { RaisingHash.new }

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
end
