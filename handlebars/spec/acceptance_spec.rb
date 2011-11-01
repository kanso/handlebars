require "spec_helper"

class TestContext
  class TestModule
    attr_reader :name, :tests

    def initialize(name)
      @name = name
      @tests = []
    end
  end

  attr_reader :modules

  def initialize
    @modules = []
  end

  def module(name)
    @modules << TestModule.new(name)
  end

  def test(name, function)
    @modules.last.tests << [name, function]
  end
end

test_context = TestContext.new
js_context = Handlebars::Spec::CONTEXT

Module.new do
  extend Test::Unit::Assertions

  def self.js_backtrace(context)
    begin
      context.eval("throw")
    rescue V8::JSError => e
      return e.backtrace(:javascript)
    end
  end

  js_context["p"] = proc do |str|
    p str
  end

  js_context["ok"] = proc do |ok, message|
    js_context["$$RSPEC1$$"] = ok

    result = js_context.eval("!!$$RSPEC1$$")

    message ||= "#{ok} was not truthy"

    unless result
      backtrace = js_backtrace(js_context)
      message << "\n#{backtrace.join("\n")}"
    end

    assert result, message
  end

  js_context["equals"] = proc do |first, second, message|
    js_context["$$RSPEC1$$"] = first
    js_context["$$RSPEC2$$"] = second

    result = js_context.eval("$$RSPEC1$$ == $$RSPEC2$$")

    message ||= "#{first} did not == #{second}"

    unless result
      backtrace = js_backtrace(js_context)
      message << "\n#{backtrace.join("\n")}"
    end

    assert result, message
  end

  js_context["equal"] = js_context["equals"]

  js_context["module"] = proc do |name|
    test_context.module(name)
  end

  js_context["test"] = proc do |name, function|
    test_context.test(name, function)
  end

  local = Regexp.escape(File.expand_path(Dir.pwd))
  qunit_spec = File.expand_path("../qunit_spec.js", __FILE__)
  js_context.load(qunit_spec.sub(/^#{local}\//, ''))
end

test_context.modules.each do |mod|
  describe mod.name do
    mod.tests.each do |name, function|
      it name do
        function.call
      end
    end
  end
end
