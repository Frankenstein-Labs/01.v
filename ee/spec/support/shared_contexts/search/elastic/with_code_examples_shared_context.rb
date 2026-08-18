# frozen_string_literal: true

RSpec.shared_context 'with code examples' do
  let(:code_examples) do
    {
      'perlMethodCall' => '$my_perl_object->perlMethodCall',
      '"absolute_with_specials.txt"' => '/a/longer/file-path/absolute_with_specials.txt',
      '"components-within-slashes"' => '/file-path/components-within-slashes/',
      'bar\(x\)' => 'Foo.bar(x)',
      'someSingleColonMethodCall' => 'LanguageWithSingleColon:someSingleColonMethodCall',
      'javaLangStaticMethodCall' => 'MyJavaClass::javaLangStaticMethodCall',
      'IllegalStateException' => 'java.lang.IllegalStateException',
      'tokenAfterParentheses' => 'ParenthesesBetweenTokens)tokenAfterParentheses',
      'ruby_call_method_123' => 'RubyClassInvoking.ruby_call_method_123(with_arg)',
      'ruby_method_call' => 'RubyClassInvoking.ruby_method_call(with_arg)',
      '#ambitious-planning' => 'We [plan ambitiously](#ambitious-planning).',
      'ambitious-planning' => 'We [plan ambitiously](#ambitious-planning).',
      'tokenAfterCommaWithNoSpace' => 'WouldHappenInManyLanguages,tokenAfterCommaWithNoSpace',
      'missing_token_around_equals' => 'a.b.c=missing_token_around_equals',
      'and;colons:too$' => 'and;colons:too$',
      '"differeñt-lønguage.txt"' => 'another/file-path/differeñt-lønguage.txt',
      '"relative-with-specials.txt"' => 'another/file-path/relative-with-specials.txt',
      'ruby_method_123' => 'def self.ruby_method_123(ruby_another_method_arg)',
      'ruby_method_name' => 'def self.ruby_method_name(ruby_method_arg)',
      '"dots.also.need.testing"' => 'dots.also.need.testing',
      '.testing' => 'dots.also.need.testing',
      'dots' => 'dots.also.need.testing',
      'also.need' => 'dots.also.need.testing',
      'need' => 'dots.also.need.testing',
      'tests-image' => 'extends: .gitlab-tests-image',
      'gitlab-tests' => 'extends: .gitlab-tests-image',
      'gitlab-tests-image' => 'extends: .gitlab-tests-image',
      'foo/bar' => 'https://s3.amazonaws.com/foo/bar/baz.png',
      'https://test.or.dev.com/repository' => 'https://test.or.dev.com/repository/maven-all',
      'test.or.dev.com/repository/maven-all' => 'https://test.or.dev.com/repository/maven-all',
      'repository/maven-all' => 'https://test.or.dev.com/repository/maven-all',
      'https://test.or.dev.com/repository/maven-all' => 'https://test.or.dev.com/repository/maven-all',
      'bar-baz-conventions' => 'id("foo.bar-baz-conventions")',
      'baz-conventions' => 'id("foo.bar-baz-conventions")',
      'baz' => 'id("foo.bar-baz-conventions")',
      'bikes-3.4' => 'include "bikes-3.4"',
      'sql_log_bin' => 'q = "SET @@session.sql_log_bin=0;"',
      'sql_log_bin=0' => 'q = "SET @@session.sql_log_bin=0;"',
      'v3/delData' => 'uri: "v3/delData"',
      '"us-east-2"' => 'us-east-2'
    }
  end
end
