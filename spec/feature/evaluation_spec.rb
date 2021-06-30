require 'spec_helper'

RSpec.describe 'evaluate_script' do
  subject { evaluate_script(expression) }

  context '[number] 1 + 1' do
    let(:expression) { '1 + 1' }
    it { is_expected.to eq(2) }
  end

  context '[string] "1" + 1' do
    let(:expression) { '"1" + 1' }
    it { is_expected.to eq("11") }
  end

  context '[DOMElement]' do
    before {
      visit 'about:blank'
      execute_script('document.write("<h1>It works!</h1>")')
    }

    let(:expression) { 'document.querySelector("h1")' }
    it 'is expected to be an instance of Capybara::Node::Element' do
      is_expected.to be_a(Capybara::Node::Element)
      expect(subject.text).to eq('It works!')
    end
  end

  context '[Array]' do
    before {
      visit 'about:blank'
      execute_script('document.write("<h1>It works!</h1>")')
    }

    let(:expression) { '[1, "11", document.querySelector("h1")]' }
    it 'contains Capybara::Node::Element' do
      expect(subject[0]).to eq(1)
      expect(subject[1]).to eq("11")
      expect(subject[2]).to be_a(Capybara::Node::Element)
      expect(subject[2].text).to eq('It works!')
    end
  end

  context '[object (Hash)]' do
    before {
      visit 'about:blank'
      execute_script('document.write("<h1>It works!</h1>")')
    }

    let(:expression) { '{ int: 1, str: "11", node: document.querySelector("h1") }' }
    it 'contains Capybara::Node::Element' do
      expect(subject['int']).to eq(1)
      expect(subject['str']).to eq("11")
      expect(subject['node']).to be_a(Capybara::Node::Element)
      expect(subject['node'].text).to eq('It works!')
    end
  end
end
