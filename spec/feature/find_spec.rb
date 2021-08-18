require 'spec_helper'

RSpec.describe 'find' do
  before {
    visit 'about:blank'
    execute_script('document.write("<h1>It works!</h1><input type=\"text\" name=\"q\" id=\"input_text\" />")')
  }

  it 'can find by id' do
    node = find('#input_text')
    expect(node['id']).to eq('input_text')
  end

  it 'can find by CSS selector' do
    node = find('input[name="q"]')
    expect(node['id']).to eq('input_text')
  end

  it 'can find by XPath query' do
    node = find(:xpath, '//input[@name="q"]')
    expect(node['id']).to eq('input_text')
  end
end
