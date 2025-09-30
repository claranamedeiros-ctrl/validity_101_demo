#!/usr/bin/env ruby

# Script to set up the validity-101-agent prompt in PromptEngine

require_relative 'config/environment'

puts "Setting up validity-101-agent prompt in PromptEngine..."

# Read the prompt templates
system_prompt = File.read('system.erb')
user_prompt = File.read('user.erb')

begin
  # Create or update the prompt
  prompt = PromptEngine::Prompt.find_or_initialize_by(name: 'validity-101-agent')

  prompt.assign_attributes(
    name: 'validity-101-agent',
    description: 'Patent validity analysis using Alice Test methodology',
    system_message: system_prompt,
    content: user_prompt,
    model: ENV.fetch('OPENAI_MODEL', 'gpt-4o'),
    temperature: 0.1,
    max_tokens: 1200,
    status: 'active'
  )

  if prompt.save!
    puts "✅ Successfully created/updated prompt: validity-101-agent"
    puts "   - Name: #{prompt.name}"
    puts "   - Model: #{prompt.model}"
    puts "   - Temperature: #{prompt.temperature}"
    puts "   - Status: #{prompt.status}"
  end

rescue => e
  puts "❌ Failed to create prompt: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.first(5)
  exit 1
end

puts "\n🎉 Prompt setup complete! Ready to run bin/rails validity:eval"