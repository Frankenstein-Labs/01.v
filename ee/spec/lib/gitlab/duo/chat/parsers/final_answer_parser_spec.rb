# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Chat::Parsers::FinalAnswerParser, feature_category: :duo_chat do
  describe '.sanitize' do
    subject(:sanitized_answer) { described_class.sanitize(final_answer) }

    shared_examples 'sanitizes URLs correctly' do |input, expected_output|
      let(:final_answer) { input }

      it 'sanitizes final_answer as expected' do
        expect(sanitized_answer).to eq(expected_output)
      end
    end

    context 'when final_answer is nil' do
      let(:final_answer) { nil }

      it 'returns nil' do
        expect(sanitized_answer).to be_nil
      end
    end

    context 'when there are no URLs in the final answer' do
      include_examples 'sanitizes URLs correctly',
        'There are no URLs to be sanitized here.',
        'There are no URLs to be sanitized here.'
    end

    # Standard Plain Text Style Links
    context 'when a standard plaintext URL has a username and password in the url2' do
      include_examples 'sanitizes URLs correctly',
        'https://john:secretpass123@example.com/dashboard',
        '`https://john:secretpass123@example.com/dashboard`'
    end

    context 'when a standard plaintext URL has encoded characters' do
      include_examples 'sanitizes URLs correctly',
        'Try https://example.com/path%20with%20spaces',
        'Try `https://example.com/path%20with%20spaces`'
    end

    context 'when a standard plaintext URL has special characters' do
      include_examples 'sanitizes URLs correctly',
        'Check out https://example.com/path?param=value&another=123#fragment',
        'Check out `https://example.com/path?param=value&another=123#fragment`'
    end

    context 'when a standard plaintext URL has backticks around part of it' do
      include_examples 'sanitizes URLs correctly',
        'With backticks around part of the URL `http://`example.com',
        'With backticks around part of the URL `http://`example.com'
    end

    context 'when a standard plaintext URL has backticks inside it' do
      include_examples 'sanitizes URLs correctly',
        'With backticks inside the URL http://exam`ple.com',
        'With backticks inside the URL `http://exam`ple.com'
    end

    context 'when a standard plaintext URL has backticks at the end' do
      include_examples 'sanitizes URLs correctly',
        'With backticks at the end of the URL http://example.com`',
        'With backticks at the end of the URL `http://example.com`'
    end

    context 'when a standard plaintext URL has backticks in a complex pattern' do
      include_examples 'sanitizes URLs correctly',
        'Mixed backticks and URL: `start http://example.com `end',
        'Mixed backticks and URL: `start http://example.com` `end'
    end

    context 'when a standard plaintext URL has port and query parameters' do
      include_examples 'sanitizes URLs correctly',
        'https://example.com:8080/path?param1=value1&param2=value2',
        '`https://example.com:8080/path?param1=value1&param2=value2`'
    end

    context 'when a standard plaintext URL has username, password, and hash framgments' do
      include_examples 'sanitizes URLs correctly',
        'https://user:password@example.com/dashboard#section1',
        '`https://user:password@example.com/dashboard#section1`'
    end

    context 'when a standard plaintext URL has port, query parameters, and hash fragment' do
      include_examples 'sanitizes URLs correctly',
        'https://api.example.com:443/v1/users?filter=active#results',
        '`https://api.example.com:443/v1/users?filter=active#results`'
    end

    context 'when a standard plaintext URL user, password, port, and query parameters' do
      include_examples 'sanitizes URLs correctly',
        'https://admin:secretpass@database.example.com:5432/records?format=json',
        '`https://admin:secretpass@database.example.com:5432/records?format=json`'
    end

    context 'when a standard plaintext URL has all components' do
      include_examples 'sanitizes URLs correctly',
        'https://john:pass123@subdomain.example.com:8443/app/profile?lang=en&theme=dark#settings',
        '`https://john:pass123@subdomain.example.com:8443/app/profile?lang=en&theme=dark#settings`'
    end

    context 'when a standard plaintext URL has user, password (with @), query parameters with special characters' do
      include_examples 'sanitizes URLs correctly',
        'https://user:p@ssw0rd@example.com/search?q=complex+query&filter[]=category1&filter[]=category2',
        '`https://user:p@ssw0rd`@example.com/search?q=complex+query&filter[]=category1&filter[]=category2'
    end

    context 'when a standard plaintext URL has user, password, query parameters with special characters' do
      include_examples 'sanitizes URLs correctly',
        'https://user:pa$$w0rd@example.com/search?q=complex+query&filter[]=category1&filter[]=category2',
        '`https://user:pa$$w0rd@example.com/search?q=complex+query&filter[]=category1&filter[]=category2`'
    end

    context 'when a standard plaintext URL is within parentheses' do
      include_examples 'sanitizes URLs correctly',
        'For more info (see https://example.com)',
        'For more info (see `https://example.com`)'
    end

    context 'when a standard plaintext URL is within HTML entities' do
      include_examples 'sanitizes URLs correctly',
        'Visit &lt;https://example.com&gt; for more',
        'Visit <`https://example.com`> for more'
    end

    context 'when a standard plaintext URL is preceded by an odd number of backticks' do
      include_examples 'sanitizes URLs correctly',
        'Uneven backticks: ```http://example.com',
        'Uneven backticks: ` ` `http://example.com`'
    end

    context 'when a standard plaintext URL is a IPv6 address with port and query parameters' do
      include_examples 'sanitizes URLs correctly',
        'https://[2001:db8::1]:8080/api?version=2&format=xml',
        '`https://[2001:db8::1]:8080/api?version=2&format=xml`'
    end

    context 'when standard plaintext URLs have port numbers' do
      include_examples 'sanitizes URLs correctly',
        'Connect to http://google.com:3000 or https://example.com:8080',
        'Connect to `http://google.com:3000` or `https://example.com:8080`'
    end

    context 'when standard plaintext URLs have unusual TLDs' do
      include_examples 'sanitizes URLs correctly',
        'Check out https://example.co.uk and http://test.io',
        'Check out `https://example.co.uk` and `http://test.io`'
    end

    context 'when standard plaintext URLs have different protocols' do
      include_examples 'sanitizes URLs correctly',
        'Try ftp://example.com or mailto:user@example.com',
        'Try `ftp://example.com` or `mailto:user@example.com`'
    end

    context 'when standard plaintext URLs have various prefixes and suffixes' do
      include_examples 'sanitizes URLs correctly',
        'URLs: (https://example.com), https://test.com.',
        'URLs: (`https://example.com`), `https://test.com`.'
    end

    context 'when standard plaintext URLs have fragments with special characters' do
      include_examples 'sanitizes URLs correctly',
        'See https://example.com/page#section-1.2&param=value',
        'See `https://example.com/page#section-1.2&param=value`'
    end

    context 'when standard plaintext URLs have various backtick tricks' do
      include_examples 'sanitizes URLs correctly',
        'Multiple URLs with tricks: `http://`example.com and http://exam`ple2.com`',
        'Multiple URLs with tricks: `http://`example.com and `http://exam`ple2.com`'
    end

    context 'when standard plaintext URLs are provided' do
      include_examples 'sanitizes URLs correctly',
        'Check out https://example.com and http://test.com',
        'Check out `https://example.com` and `http://test.com`'
    end

    context 'when standard plaintext URLs are in different text formats' do
      include_examples 'sanitizes URLs correctly',
        "Normal https://example.com\nBOLD **https://bold.com**\nItalic *https://italic.com*",
        "Normal `https://example.com`\nBOLD **`https://bold.com`**\nItalic *`https://italic.com`*"
    end

    context 'when standard plaintext URLs are IP addresses' do
      include_examples 'sanitizes URLs correctly',
        'Access http://192.168.1.1 or https://[2001:db8::1]',
        'Access `http://192.168.1.1` or `https://[2001:db8::1]`'
    end

    context 'when standard plaintext URLs are at the beginning or end of the text' do
      include_examples 'sanitizes URLs correctly',
        'https://start.com Some text https://end.com',
        '`https://start.com` Some text `https://end.com`'
    end

    context 'when standard plaintext URLs are consecutively after one another' do
      include_examples 'sanitizes URLs correctly',
        'Visit https://example1.com https://example2.com',
        'Visit `https://example1.com` `https://example2.com`'
    end

    context 'when standard plaintext URLs are mixed with authorized and unauthorized domains' do
      include_examples 'sanitizes URLs correctly',
        'Visit https://docs.gitlab.com and https://example.com for info',
        'Visit https://docs.gitlab.com and `https://example.com` for info'
    end

    context 'when standard plaintext URLs are incomplete or malformed' do
      include_examples 'sanitizes URLs correctly',
        'Check www.example.com or http:// or https://',
        'Check `www.example.com` or http:// or https://'
    end

    context 'when standard plaintext URLs are adjacent to punctuation' do
      include_examples 'sanitizes URLs correctly',
        'Visit https://example.com, then (https://another.com).',
        'Visit `https://example.com`, then (`https://another.com`).'
    end

    # HTML Style Links
    context 'when a HTML URL is provided' do
      include_examples 'sanitizes URLs correctly',
        '<a href="http://example.com">Link</a>',
        '`<a href="http://example.com">Link</a>`'
    end

    context 'when an HTML URL is authorized' do
      include_examples 'sanitizes URLs correctly',
        '<a href="https://docs.gitlab.com">GitLab Docs</a>',
        '<a href="https://docs.gitlab.com">GitLab Docs</a>'
    end

    context 'when a HTML URL has a beginning backtick' do
      include_examples 'sanitizes URLs correctly',
        'With a beginning backtick ` but no ending <a href="http://example.com">Link</a>',
        'With a beginning backtick ` but no ending <a href="http://example.com">Link</a>`'
    end

    context 'when a HTML URL has an ending backtick' do
      include_examples 'sanitizes URLs correctly',
        'With a ending backtick but no beginning <a href="http://example.com">Link</a>`',
        'With a ending backtick but no beginning `<a href="http://example.com">Link</a>`'
    end

    context 'when a HTML URL has encoded characters' do
      include_examples 'sanitizes URLs correctly',
        'Visit <a href="https://example.com/path%20with%20spaces">Example</a>',
        'Visit `<a href="https://example.com/path%20with%20spaces">Example</a>`'
    end

    context 'when a HTML URL has a username and password' do
      include_examples 'sanitizes URLs correctly',
        'Access <a href="https://john:secretpass123@example.com/dashboard">dashboard</a>',
        'Access `<a href="https://john:secretpass123@example.com/dashboard">dashboard</a>`'
    end

    context 'when a HTML URL has special characters' do
      include_examples 'sanitizes URLs correctly',
        'Check <a href="https://example.com/path?param=value&another=123#fragment">Link</a>',
        'Check `<a href="https://example.com/path?param=value&another=123#fragment">Link</a>`'
    end

    context 'when a HTML URL has port and query parameters' do
      include_examples 'sanitizes URLs correctly',
        '<a href="https://example.com:8080/path?param1=value1&param2=value2">Complex Link</a>',
        '`<a href="https://example.com:8080/path?param1=value1&param2=value2">Complex Link</a>`'
    end

    context 'when a HTML URL has all components' do
      include_examples 'sanitizes URLs correctly',
        '<a href="https://john:pass123@subdomain.example.com:8443/app/profile?lang=en&theme=dark#settings">' \
          'Full Link</a>',
        '`<a href="https://john:pass123@subdomain.example.com:8443/app/profile?lang=en&theme=dark#settings">' \
          'Full Link</a>`'
    end

    context 'when a HTML URL has backticks inside it and before it' do
      include_examples 'sanitizes URLs correctly',
        'Backticks in HTML: `<a href="http://`exam````ple.com">Link</a>',
        'Backticks in HTML: `<a href="http://example.com">Link</a>`'
    end

    # Markdown Style Links

    context 'when a markdown URL is provided' do
      include_examples 'sanitizes URLs correctly',
        '[Link](http://example.com)',
        '`[Link](http://example.com)`'
    end

    context 'when a markdown URL is authorized' do
      include_examples 'sanitizes URLs correctly',
        '[GitLab Docs](https://docs.gitlab.com)',
        '[GitLab Docs](https://docs.gitlab.com)'
    end

    context 'when a Markdown URL has a beginning backtick' do
      include_examples 'sanitizes URLs correctly',
        'With a beginning backtick but no ending `[Link](http://example.com)',
        'With a beginning backtick but no ending `[Link](http://example.com)`'
    end

    context 'when a Markdown URL has an ending backtick' do
      include_examples 'sanitizes URLs correctly',
        'With an ending backtick but no beginning [Link](http://example.com)`',
        'With an ending backtick but no beginning `[Link](http://example.com)`'
    end

    context 'when a markdown URL has a username and password' do
      include_examples 'sanitizes URLs correctly',
        '[dashboard](https://john:secretpass123@example.com/dashboard)',
        '`[dashboard](https://john:secretpass123@example.com/dashboard)`'
    end

    context 'when a markdown URL has encoded characters' do
      include_examples 'sanitizes URLs correctly',
        '[Example](https://example.com/path%20with%20spaces)',
        '`[Example](https://example.com/path%20with%20spaces)`'
    end

    context 'when a markdown URL has special characters and &amp;' do
      include_examples 'sanitizes URLs correctly',
        '[Link](https://example.com/path?param=value&amp;another=123#fragment)',
        '`[Link](https://example.com/path?param=value&amp;another=123#fragment)`'
    end

    context 'when a markdown URL has special characters' do
      include_examples 'sanitizes URLs correctly',
        '[Link](https://example.com/path?param=value&another=123#fragment)',
        '`[Link](https://example.com/path?param=value&another=123#fragment)`'
    end

    context 'when a markdown URL has port and query parameters' do
      include_examples 'sanitizes URLs correctly',
        '[Complex Link](https://example.com:8080/path?param1=value1&param2=value2)',
        '`[Complex Link](https://example.com:8080/path?param1=value1&param2=value2)`'
    end

    context 'when a markdown URL has all components' do
      include_examples 'sanitizes URLs correctly',
        '[Full Link](https://john:pass123@subdomain.example.com:8443/app/profile?lang=en&theme=dark#settings)',
        '`[Full Link](https://john:pass123@subdomain.example.com:8443/app/profile?lang=en&theme=dark#settings)`'
    end

    # Mixed Scenarios
    context 'when HTML and markdown URLs are in the same response' do
      include_examples 'sanitizes URLs correctly',
        'Check <a href="https://example.com">HTML</a> and [Markdown](https://example.org)',
        'Check `<a href="https://example.com">HTML</a>` and `[Markdown](https://example.org)`'
    end

    context 'when HTML and markdown URLs are in different text formats' do
      include_examples 'sanitizes URLs correctly',
        "Normal <a href=\"https://example.com\">Link</a>\nBOLD **[Bold](https://bold.com)**\nItalic *<a href=\"https://italic.com\">Italic</a>*",
        "Normal `<a href=\"https://example.com\">Link</a>`\nBOLD **`[Bold](https://bold.com)`**\nItalic *`<a href=\"https://italic.com\">Italic</a>`*"
    end

    context 'when HTML and markdown URLs are IP addresses' do
      include_examples 'sanitizes URLs correctly',
        'IPv4 <a href="http://192.168.1.1">Link</a> and IPv6 [Link](https://[2001:db8::1])',
        'IPv4 `<a href="http://192.168.1.1">Link</a>` and IPv6 `[Link](https://[2001:db8::1])`'
    end

    context 'when HTML and markdown URLs are at the beginning or end of the text' do
      include_examples 'sanitizes URLs correctly',
        '<a href="https://start.com">Start</a> Some text [End](https://end.com)',
        '`<a href="https://start.com">Start</a>` Some text `[End](https://end.com)`'
    end

    context 'when HTML and markdown URLs are adjacent to punctuation' do
      include_examples 'sanitizes URLs correctly',
        'Visit <a href="https://example.com">Link</a>, then ([Another](https://another.com)).',
        'Visit `<a href="https://example.com">Link</a>`, then (`[Another](https://another.com)`).'
    end

    context 'when markdown and standard URLs are side by side' do
      include_examples 'sanitizes URLs correctly',
        '[google](https://google.com)https://google.com',
        '`[google](https://google.com)` `https://google.com`'
    end

    context 'when HTML and stardard URLs are side by side' do
      include_examples 'sanitizes URLs correctly',
        '<a href="https://example.com">Link</a>https://google.com',
        '`<a href="https://example.com">Link</a>` `https://google.com`'
    end

    context 'when markdown and standard URLs are side by side and one needs only front escape' do
      include_examples 'sanitizes URLs correctly',
        '[google](https://google.com)`https://google.com',
        '`[google](https://google.com)` `https://google.com`'
    end

    context 'when markdown and standard URLs are side by side and one needs only end escape' do
      include_examples 'sanitizes URLs correctly',
        '`[google](https://google.com)https://google.com',
        '`[google](https://google.com)` `https://google.com`'
    end

    context 'when markdown and standard URLs are side by side with different escape needs' do
      include_examples 'sanitizes URLs correctly',
        '[google](https://google.com)``https://google.com',
        '`[google](https://google.com)` `https://google.com`'
    end

    context 'when markdown and relative URLs' do
      include_examples 'sanitizes URLs correctly',
        '[Sources](/example/source)',
        '[Sources](/example/source)'
    end

    context 'when markdown and relative URL but it contains a real URL within it' do
      include_examples 'sanitizes URLs correctly',
        '[Sources](/example/https://example.com/source)',
        '`[Sources](/example/https://example.com/source)`'
    end

    # Single Line Response With Complex Escaped Patterns
    context 'when URLs have multiple spaced out evenly escaped backticks and other oddities' do
      include_examples 'sanitizes URLs correctly',
        "When not in a code block, the text:  ```  Partially escaped Markdown link: \\` \\` " \
          "\\`[GitLab](https://www.gitlab.com) ```  would look like this:  Partially escaped Markdown link: \` \` " \
          "\```[GitLab](https://www.gitlab.com)` ```  Here's an explanation of how it's rendered:  1. \"Partially " \
          "escaped Markdown link:\" appears as plain text. 2. The first two `\\`` sequences are rendered as `\`` " \
          "(a backslash followed by a backtick). 3. The third `\\``` sequence is rendered as `\```, which starts an " \
          "inline code block. 4. `[GitLab](https://www.gitlab.com)` appears as plain text within the inline code " \
          "block. 5. The final ` ```` (three backticks) close the inline code block.",
        "When not in a code block, the text:  ` ` `  Partially escaped Markdown link: \\ ` \\ ` \\ ` " \
          "`[GitLab](https://www.gitlab.com)` ` ` `  would look like this:  Partially escaped Markdown link: ` ` ` " \
          "` ` `[GitLab](https://www.gitlab.com)` ` ` `  Here's an explanation of how it's rendered:  " \
          "1. \"Partially escaped Markdown link:\" appears as plain text. 2. The first two `\\ ` ` sequences are " \
          "rendered as ` ` ` (a backslash followed by a backtick). 3. The third `\\ ` ` ` sequence is rendered as " \
          "` ` ` `, which starts an inline code block. 4. ` `[GitLab](https://www.gitlab.com)` appears as plain text " \
          "within the inline code block. 5. The final ` ` ` ` ` (three backticks) close the inline code block."
    end

    context 'when URLs have a large number of backslashes before a backtick' do
      include_examples 'sanitizes URLs correctly',
        '`[GitLab](https://www.gitlab.com) followed by \\\\\\` ``[google](https://google.com) and another normal link https://testing.com',
        '`[GitLab](https://www.gitlab.com)` followed by \\\\\\ ` ` `[google](https://google.com)` and another normal ' \
          'link `https://testing.com`'
    end

    context 'when URLs have the beginning escaped and other oddities' do
      include_examples 'sanitizes URLs correctly',
        'Partially escaped Markdown link: `\[GitLab](https://www.gitlab.com) followed by \\\` ' \
          '``[google](https://google.com) and another normal link https://testing.com',
        'Partially escaped Markdown link: `\\ [GitLab](https://www.gitlab.com)` followed by \\\\ ` ` ' \
          '`[google](https://google.com)` and another normal link `https://testing.com`'
    end

    context 'when URLs have complex backtick escapes but are already escaped' do
      include_examples 'sanitizes URLs correctly',
        'Partially escaped Markdown link: \\` \\` \\``[GitLab](https://www.gitlab.com)',
        'Partially escaped Markdown link: \\ ` \\ ` \\ ` ` `[GitLab](https://www.gitlab.com)`'
    end

    context 'when URL start is escaped and requires front and end and start is backticks' do
      include_examples 'sanitizes URLs correctly',
        'Partially escaped Markdown link: \[GitLab](https://www.gitlab.com)',
        'Partially escaped Markdown link: \ `[GitLab](https://www.gitlab.com)`'
    end

    context 'when URL start is escaped and requires front backtick' do
      include_examples 'sanitizes URLs correctly',
        'Partially escaped Markdown link: \[GitLab](https://www.gitlab.com)`',
        'Partially escaped Markdown link: \ `[GitLab](https://www.gitlab.com)`'
    end

    context 'when URL start is an escaped backtick and requires additional front backtick' do
      include_examples 'sanitizes URLs correctly',
        'Partially escaped Markdown link: `\`[GitLab](https://www.gitlab.com)`',
        'Partially escaped Markdown link: `\\ ` `[GitLab](https://www.gitlab.com)`'
    end

    context 'when URL start is an escaped backtick and requires an end backtick' do
      include_examples 'sanitizes URLs correctly',
        'Partially escaped Markdown link: \`[GitLab](https://www.gitlab.com)',
        'Partially escaped Markdown link: \ `[GitLab](https://www.gitlab.com)`'
    end

    # Complex Testing Scenarios
    context 'when URLs are in list items' do
      let(:final_answer) do
        <<~MARKDOWN
          - First item
          - https://example1.com
          - Third item https://example2.com
        MARKDOWN
      end

      it 'sanitizes URLs in list items correctly' do
        expected =
          <<~MARKDOWN
            - First item
            - `https://example1.com`
            - Third item `https://example2.com`
          MARKDOWN
        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when the response contains a HTML URL and text explaining what an <a> tag is' do
      let(:final_answer) do
        <<~MARKDOWN
          Here's a `<a>` tag link with backticks.
          Each `<a>` tag has two parts: the visible link text and the actual URL, which is hidden in the `href` attribute.
          In this case, the visible link text is "Example" and the URL is "http://example.com". This is closed with `</a>`
          You can click on the link text to visit the URL.

          <a>https://example.com</a>

          And some normal text after.
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            Here's a `<a>` tag link with backticks.
            Each `<a>` tag has two parts: the visible link text and the actual URL, which is hidden in the `href` attribute.
            In this case, the visible link text is "Example" and the URL is "`http://example.com`". This is closed with `</a>`
            You can click on the link text to visit the URL.

            <a>`https://example.com`</a>

            And some normal text after.
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when the response contains a HTML URL and text explaining what an <a> tag is after the URL' do
      let(:final_answer) do
        <<~MARKDOWN
            The HTML code and plain text you provided would appear exactly like this when rendered:

            <a href="https://www.google.com">Google Search</a>

            And it would look like https://google.com

            To explain in detail:

            The HTML anchor tag <a href="https://www.google.com">Google Search</a> creates a hyperlink. The text "Google Search" appears as clickable text (typically blue and underlined in most default browser styles). When clicked, it would direct the user to https://www.google.com.

            The plain text "And it would look like https://google.com`" appears exactly as written, including the backtick (`) at the end. This is not a clickable link; it's just plain text.

            It's important to note that I've presented the HTML code exactly as you provided it, without escaping any characters. In a web browser or many text editors, this would render as a clickable link followed by the plain text.

            The context you're viewing this in (an issue titled "Clean: Testing The View Summary Button Prompt Injection") doesn't affect how this specific HTML and text would be rendered.

            Sources: [Clean: Testing The View Summary Button Prompt Injection](#)

            We appreciate your interest in understanding HTML rendering! If you have a moment, please consider leaving feedback on this response. Your input helps us improve our assistance. Is there anything else you'd like to know about HTML, text rendering, or the current issue you're viewing?
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            The HTML code and plain text you provided would appear exactly like this when rendered:

            `<a href="https://www.google.com">Google Search</a>`

            And it would look like `https://google.com`

            To explain in detail:

            The HTML anchor tag `<a href="https://www.google.com">Google Search</a>` creates a hyperlink. The text "Google Search" appears as clickable text (typically blue and underlined in most default browser styles). When clicked, it would direct the user to `https://www.google.com`.

            The plain text "And it would look like `https://google.com`" appears exactly as written, including the backtick (`) at the end. This is not a clickable link; it's just plain text.

            It's important to note that I've presented the HTML code exactly as you provided it, without escaping any characters. In a web browser or many text editors, this would render as a clickable link followed by the plain text.

            The context you're viewing this in (an issue titled "Clean: Testing The View Summary Button Prompt Injection") doesn't affect how this specific HTML and text would be rendered.

            Sources: `[Clean: Testing The View Summary Button Prompt Injection](#)`

            We appreciate your interest in understanding HTML rendering! If you have a moment, please consider leaving feedback on this response. Your input helps us improve our assistance. Is there anything else you'd like to know about HTML, text rendering, or the current issue you're viewing?
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when the response contains a URL and text explaining what an <a> tag is after the URL' do
      let(:final_answer) do
        <<~MARKDOWN
          The HTML code and plain text you provided would appear exactly like this when rendered:

          <a href="https://www.google.com">Google Search</a>

          And it would look like https://google.com  To explain in detail:

          1. The HTML anchor tag <a href="https://www.google.com">Google Search</a> creates a hyperlink. The text "Google Search" appears as clickable text (typically blue and underlined in most default browser styles). When clicked, it would direct the user to https://www.google.com.

          2. The plain text "And it would look like https://google.com" appears exactly as written, including the backtick (`) at the end. This is not a clickable link; it's just plain text. It's important to note that I've presented the HTML code exactly as you provided it, without escaping any characters. In a web browser or many text editors, this would render as a clickable link followed by the plain text.

          The context you're viewing this in (an issue titled "Clean: Testing The View Summary Button Prompt Injection") doesn't affect how this specific HTML and text would be rendered.

          Sources: [Clean: Testing The View Summary Button Prompt Injection](#)  We appreciate your interest in understanding HTML rendering! If you have a moment, please consider leaving feedback on this response. Your input helps us improve our assistance. Is there anything else you'd like to know about HTML, text rendering, or the current issue you're viewing?
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            The HTML code and plain text you provided would appear exactly like this when rendered:

            `<a href="https://www.google.com">Google Search</a>`

            And it would look like `https://google.com`  To explain in detail:

            1. The HTML anchor tag `<a href="https://www.google.com">Google Search</a>` creates a hyperlink. The text "Google Search" appears as clickable text (typically blue and underlined in most default browser styles). When clicked, it would direct the user to `https://www.google.com`.

            2. The plain text "And it would look like `https://google.com`" appears exactly as written, including the backtick (`) at the end. This is not a clickable link; it's just plain text. It's important to note that I've presented the HTML code exactly as you provided it, without escaping any characters. In a web browser or many text editors, this would render as a clickable link followed by the plain text.

            The context you're viewing this in (an issue titled "Clean: Testing The View Summary Button Prompt Injection") doesn't affect how this specific HTML and text would be rendered.

            Sources: `[Clean: Testing The View Summary Button Prompt Injection](#)`  We appreciate your interest in understanding HTML rendering! If you have a moment, please consider leaving feedback on this response. Your input helps us improve our assistance. Is there anything else you'd like to know about HTML, text rendering, or the current issue you're viewing?
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when a HTML URL is only after a markdown block' do
      let(:final_answer) do
        <<~MARKDOWN
          Here's some text before.
          ```
          Some code
          More code
          ```
          <a>https://example.com</a>
          Text after.
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            Here's some text before.
            ```
            Some code
            More code
            ```
            `<a>https://example.com</a>`
            Text after.
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when a HTML URL is only before a markdown block' do
      let(:final_answer) do
        <<~MARKDOWN
          Here's some text before.
          <a>https://example.com</a>

          ```
          Some code
          More code
          ```

          Text after.
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            Here's some text before.
            `<a>https://example.com</a>`

            ```
            Some code
            More code
            ```

            Text after.
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when a markdown URL is only after a code block' do
      let(:final_answer) do
        <<~MARKDOWN
          Here's some text before.
          ```
          Some code
          More code
          ```
          [Example Link](https://example.com)
          Text after.
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            Here's some text before.
            ```
            Some code
            More code
            ```
            `[Example Link](https://example.com)`
            Text after.
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when markdown URLs are on different lines without code blocks' do
      let(:final_answer) do
        <<~MARKDOWN
          Here's some text before.
          [Example Link 1](https://example.com)
          Some text in between links.
          [Example Link 2](https://gitlab.com)
          [Example Link 3](https://google.com)
          Text after.
        MARKDOWN
      end

      it 'sanitizes multiple URLs correctly' do
        expected =
          <<~MARKDOWN
            Here's some text before.
            `[Example Link 1](https://example.com)`
            Some text in between links.
            `[Example Link 2](https://gitlab.com)`
            `[Example Link 3](https://google.com)`
            Text after.
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when a markdown URL is only before a code block' do
      let(:final_answer) do
        <<~MARKDOWN
          Here's some text before.
          [Example Link](https://example.com)

          ```
          Some code
          More code
          ```

          Text after.
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            Here's some text before.
            `[Example Link](https://example.com)`

            ```
            Some code
            More code
            ```

            Text after.
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when HTML URLs are on different lines without code blocks' do
      let(:final_answer) do
        <<~MARKDOWN
          Here's some text before.
          <a href="https://example.com">Example Link 1</a>
          Some text in between links.
          <a href="https://gitlab.com">Example Link 2</a>
          <a href="https://google.com">Example Link 3</a>
          Text after.
        MARKDOWN
      end

      it 'sanitizes multiple HTML URLs correctly' do
        expected =
          <<~MARKDOWN
            Here's some text before.
            `<a href="https://example.com">Example Link 1</a>`
            Some text in between links.
            `<a href="https://gitlab.com">Example Link 2</a>`
            `<a href="https://google.com">Example Link 3</a>`
            Text after.
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when sanitizing multiple types of URLs but mostly plain text URLs' do
      let(:final_answer) do
        <<~MARKDOWN
          Here's some code:
          [example](https://google.com)

          ```ruby
          https://www.google.com
          https://gitlab.com
          https://stackoverflow.com
          https://docs.python.org
          https://developer.mozilla.org
          ```

          And a https://example.com link outside the code block.
          Followed by some links
          https://www.google.com
          https://gitlab.com
          https://stackoverflow.com
          https://docs.python.org
          https://developer.mozilla.org
          testing text

          ```
          https://gitlab.com
          [example](https://google.com)
          ```

          https://docs.python.org
          https://developer.mozilla.org
          https://google.com
          some additional text for testing
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected = <<~MARKDOWN
          Here's some code:
          `[example](https://google.com)`

          ```ruby
          https://www.google.com
          https://gitlab.com
          https://stackoverflow.com
          https://docs.python.org
          https://developer.mozilla.org
          ```

          And a `https://example.com` link outside the code block.
          Followed by some links
          `https://www.google.com`
          `https://gitlab.com`
          `https://stackoverflow.com`
          `https://docs.python.org`
          `https://developer.mozilla.org`
          testing text

          ```
          https://gitlab.com
          [example](https://google.com)
          ```

          `https://docs.python.org`
          `https://developer.mozilla.org`
          `https://google.com`
          some additional text for testing
        MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when mostly markdown URLs with code blocks' do
      let(:final_answer) do
        <<~MARKDOWN
          Here's some code:
          [example](https://google.com)

          ```ruby
          [Google Search](https://www.google.com)
          [GitLab](https://gitlab.com)
          [Stack Overflow](https://stackoverflow.com)
          [Python Docs](https://docs.python.org)
          [Mozilla Developer Network](https://developer.mozilla.org)
          ```

          And a `https://example.com` link outside the code block.
          Followed by some links
          [Google Search](https://www.google.com)
          [GitLab](https://gitlab.com)
          [Stack Overflow](https://stackoverflow.com)
          [Python Docs](https://docs.python.org)
          [Mozilla Developer Network](https://developer.mozilla.org)

          ```
          [GitLab](https://gitlab.com)
          [example](https://google.com)
          ```

          [Python Docs](https://docs.python.org)
          [Mozilla Developer Network](https://developer.mozilla.org)
          https://google.com
          some additional text for testing
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected = <<~MARKDOWN
          Here's some code:
          `[example](https://google.com)`

          ```ruby
          [Google Search](https://www.google.com)
          [GitLab](https://gitlab.com)
          [Stack Overflow](https://stackoverflow.com)
          [Python Docs](https://docs.python.org)
          [Mozilla Developer Network](https://developer.mozilla.org)
          ```

          And a `https://example.com` link outside the code block.
          Followed by some links
          `[Google Search](https://www.google.com)`
          `[GitLab](https://gitlab.com)`
          `[Stack Overflow](https://stackoverflow.com)`
          `[Python Docs](https://docs.python.org)`
          `[Mozilla Developer Network](https://developer.mozilla.org)`

          ```
          [GitLab](https://gitlab.com)
          [example](https://google.com)
          ```

          `[Python Docs](https://docs.python.org)`
          `[Mozilla Developer Network](https://developer.mozilla.org)`
          `https://google.com`
          some additional text for testing
        MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when mostly HTML URLs with code blocks' do
      let(:final_answer) do
        <<~MARKDOWN
          Here's some code:
          [example](https://google.com)
          <a href="https://docs.python.org">Python Docs Link Example</a>


          ```ruby
          <a href="https://www.google.com">Google Search</a>
          <a href="https://gitlab.com">GitLab</a>
          <a href="https://stackoverflow.com">Stack Overflow</a>
          <a href="https://docs.python.org">Python Docs</a>
          <a href="https://developer.mozilla.org">Mozilla Developer Network</a>
          ```

          And a https://example.com link outside the code block.
          Followed by some a links
          <a href="https://www.google.com">Google Search</a>
          <a href="https://gitlab.com">GitLab</a>
          <a href="https://stackoverflow.com">Stack Overflow</a>
          <a href="https://docs.python.org">Python Docs</a>
          <a href="https://developer.mozilla.org">Mozilla Developer Network</a>

          ```
          <a href="https://gitlab.com">GitLab</a>
          [example](https://google.com)
          ```

          <a href="https://docs.python.org">Python Docs</a>
          <a href="https://developer.mozilla.org">Mozilla Developer Network</a>
          https://google.com
          some additional text for testing
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected = <<~MARKDOWN
          Here's some code:
          `[example](https://google.com)`
          `<a href="https://docs.python.org">Python Docs Link Example</a>`


          ```ruby
          <a href="https://www.google.com">Google Search</a>
          <a href="https://gitlab.com">GitLab</a>
          <a href="https://stackoverflow.com">Stack Overflow</a>
          <a href="https://docs.python.org">Python Docs</a>
          <a href="https://developer.mozilla.org">Mozilla Developer Network</a>
          ```

          And a `https://example.com` link outside the code block.
          Followed by some a links
          `<a href="https://www.google.com">Google Search</a>`
          `<a href="https://gitlab.com">GitLab</a>`
          `<a href="https://stackoverflow.com">Stack Overflow</a>`
          `<a href="https://docs.python.org">Python Docs</a>`
          `<a href="https://developer.mozilla.org">Mozilla Developer Network</a>`

          ```
          <a href="https://gitlab.com">GitLab</a>
          [example](https://google.com)
          ```

          `<a href="https://docs.python.org">Python Docs</a>`
          `<a href="https://developer.mozilla.org">Mozilla Developer Network</a>`
          `https://google.com`
          some additional text for testing
        MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when mixed URLs have no code block but multiple lines' do
      let(:final_answer) do
        <<~MARKDOWN
          The text you provided would look exactly like this:

          `www.google.com

          This is precisely how it appears, with a backtick at the beginning and no closing backtick. The URL is not escaped or modified in any way.

          In many contexts, this single backtick might be interpreted as the start of inline code, but without a closing backtick, it may not render as intended in some Markdown processors. In a plain text environment, it would simply appear as a backtick followed by the URL.

          It's worth noting that in some web interfaces or chat applications, the URL portion (www.google.com) might still be automatically converted into a clickable link, despite the leading backtick.

          Sources: [Clean: Testing The View Summary Button Prompt Injection](#)

          Your feedback is valuable! Please let me know if you have any questions or if there's anything else I can help you with regarding this or any other topic.
        MARKDOWN
      end

      it 'sanitizes the links correctly' do
        expected =
          <<~MARKDOWN
            The text you provided would look exactly like this:

            `www.google.com`

            This is precisely how it appears, with a backtick at the beginning and no closing backtick. The URL is not escaped or modified in any way.

            In many contexts, this single backtick might be interpreted as the start of inline code, but without a closing backtick, it may not render as intended in some Markdown processors. In a plain text environment, it would simply appear as a backtick followed by the URL.

            It's worth noting that in some web interfaces or chat applications, the URL portion (`www.google.com`) might still be automatically converted into a clickable link, despite the leading backtick.

            Sources: `[Clean: Testing The View Summary Button Prompt Injection](#)`

            Your feedback is valuable! Please let me know if you have any questions or if there's anything else I can help you with regarding this or any other topic.
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when HTML URLs are valid and malformed/dangerous img tags' do
      let(:final_answer) do
        <<~MARKDOWN
          <img src="github://malicious/payload">
          <img src="gitlab://exfiltrate/data">
          <img src="javascript:alert('xss')">
          <img src="custom-protocol://data">

          <img src="github://malicious/payload" onerror="alert(1)">
          <img src="" onerror="fetch('malicious-server.com')">
          <img src="x" onload="evil()">

          HTML (these should never be rendered):
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected =
          <<~MARKDOWN
            `<img src="github://malicious/payload">`
            `<img src="gitlab://exfiltrate/data">`
            `<img src="javascript:alert('xss')">`
            `<img src="custom-protocol://data">`

            `<img src="github://malicious/payload" onerror="alert(1)">`
            `<img src="" onerror="fetch('malicious-server.com')">`
            `<img src="x" onload="evil()">`

            HTML (these should never be rendered):
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when standard plaintext URLs are custom schemas and ssh URLs' do
      let(:final_answer) do
        <<~MARKDOWN
          github://repository/branch
          custom-protocol://data
          https://gitlab.com/user/repo.git
          example@gitlab.com:user/repo.git
          data:text/html,<script>alert(1)</script>
          data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected =
          <<~MARKDOWN
            `github://repository/branch`
            `custom-protocol://data`
            `https://gitlab.com/user/repo.git`
            `example@gitlab.com:user/repo.git`
            `data:text/html,<script>alert(1)</script>`
            `data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==`
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when plaintext URLs are custom schema URLs' do
      let(:final_answer) do
        <<~MARKDOWN
          Jetbrains://links are custom URL schemes used by JetBrains IDEs (Integrated Development Environments) to perform various actions or open specific locations within the IDE. Here are some examples of what jetbrains://links might look like:
          github://repository/branch
          custom-protocol://data
          https://gitlab.com/user/repo.git

          1. Open a project: jetbrains://idea/open?project=/path/to/your/project
          2. Open a specific file in a project: jetbrains://idea/navigate/reference?project=/path/to/project&path=src/main/java/com/example/MyClass.java
          3. Open a specific line in a file: jetbrains://idea/navigate/reference?project=/path/to/project&path=src/main/java/com/example/MyClass.java&line=42
          4. Run a specific configuration: jetbrains://idea/run?project=/path/to/project&config=MyRunConfiguration
          5. Debug a specific configuration: jetbrains://idea/debug?project=/path/to/project&config=MyDebugConfiguration
          6. Open a specific tool window: jetbrains://idea/view?project=/path/to/project&view=StructureView

          - PyCharm: jetbrains://pycharm/
          - WebStorm: jetbrains://webstorm/
          - RubyMine: jetbrains://rubymine/
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected =
          <<~MARKDOWN
            `Jetbrains://links` are custom URL schemes used by JetBrains IDEs (Integrated Development Environments) to perform various actions or open specific locations within the IDE. Here are some examples of what `jetbrains://links` might look like:
            `github://repository/branch`
            `custom-protocol://data`
            `https://gitlab.com/user/repo.git`

            1. Open a project: `jetbrains://idea/open?project=/path/to/your/project`
            2. Open a specific file in a project: `jetbrains://idea/navigate/reference?project=/path/to/project&path=src/main/java/com/example/MyClass.java`
            3. Open a specific line in a file: `jetbrains://idea/navigate/reference?project=/path/to/project&path=src/main/java/com/example/MyClass.java&line=42`
            4. Run a specific configuration: `jetbrains://idea/run?project=/path/to/project&config=MyRunConfiguration`
            5. Debug a specific configuration: `jetbrains://idea/debug?project=/path/to/project&config=MyDebugConfiguration`
            6. Open a specific tool window: `jetbrains://idea/view?project=/path/to/project&view=StructureView`

            - PyCharm: `jetbrains://pycharm/`
            - WebStorm: `jetbrains://webstorm/`
            - RubyMine: `jetbrains://rubymine/`
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when standard plaintext URLs are different types of malformed IPv6 URLs' do
      let(:final_answer) do
        <<~MARKDOWN
          Here are several examples of malformed IPv6 links in plain text, without any escaping or backticks:
          http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334
          http://[2001:db8::1234:5678
          https://[2001:db8::1234:5678]:8080]
          http://[2001:db8::1234::567]8
          ftp://[2001:db8:a0b:12f0::1
          http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80/index.html]
          https://[::ffff:192.0.2.128
          http://[2001:db8:0:0:0:0:2:1]]
          https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/
          http://[2001:db8:a0b:12f0::1/
          http://[2001:db8:0:0:0:0:0:0:1]
          https://[2001:db8::192.168.0.1]
          http://[2001:db8:a0b:12f0:::1]
          ftp://[2001:db8:3333:4444:5555:6666:7777:8888:9999]
          http://[2001:db8:0000:0000:0000:0000:0000]
          https://[::1]:80000
          http://[2001:db8::1::]
          https://[01.02.03.04]
          http://[2001:db8:1234:5678:9abc:def0:1234]
          https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334:3001]
          http://[%32%30%30%31:%64%62%38::1234:567]:8080
          http://[２００１:db８::1234:567]:8080
          http://[%32%30%30%31:db８::0x1234:0567]:8080

          This list has the following examples and some more:
          Too many segments
          Mixing IPv4 and IPv6 notation incorrectly
          Using too many colons
          Incomplete addresses
          Invalid port numbers
          Incorrect use of double colons
          Using IPv4 format within IPv6 brackets
          Missing segments
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected =
          <<~MARKDOWN
            Here are several examples of malformed IPv6 links in plain text, without any escaping or backticks:
            `http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334`
            `http://[2001:db8::1234:5678`
            `https://[2001:db8::1234:5678]:8080]`
            `http://[2001:db8::1234::567]8`
            `ftp://[2001:db8:a0b:12f0::1`
            `http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80/index.html]`
            `https://[::ffff:192.0.2.128`
            `http://[2001:db8:0:0:0:0:2:1]]`
            `https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/`
            `http://[2001:db8:a0b:12f0::1/`
            `http://[2001:db8:0:0:0:0:0:0:1]`
            `https://[2001:db8::192.168.0.1]`
            `http://[2001:db8:a0b:12f0:::1]`
            `ftp://[2001:db8:3333:4444:5555:6666:7777:8888:9999]`
            `http://[2001:db8:0000:0000:0000:0000:0000]`
            `https://[::1]:80000`
            `http://[2001:db8::1::]`
            `https://[01.02.03.04]`
            `http://[2001:db8:1234:5678:9abc:def0:1234]`
            `https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334:3001]`
            `http://[%32%30%30%31:%64%62%38::1234:567]:8080`
            `http://[２００１:db８::1234:567]:8080`
            `http://[%32%30%30%31:db８::0x1234:0567]:8080`

            This list has the following examples and some more:
            Too many segments
            Mixing IPv4 and IPv6 notation incorrectly
            Using too many colons
            Incomplete addresses
            Invalid port numbers
            Incorrect use of double colons
            Using IPv4 format within IPv6 brackets
            Missing segments
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when HTML URLs are different types of malformed IPv6 URLs' do
      let(:final_answer) do
        <<~MARKDOWN
          Here are several examples of malformed IPv6 links in plain text, without any escaping or backticks:
          <a href="http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]">http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]</a>
          <a href="http://[2001:db8::1234:5678]">http://[2001:db8::1234:5678]</a>
          <a href="https://[2001:db8::1234:5678]:8080">https://[2001:db8::1234:5678]:8080</a>
          <a href="http://[2001:db8::1234::567]8">http://[2001:db8::1234::567]8</a>
          <a href="ftp://[2001:db8:a0b:12f0::1]">ftp://[2001:db8:a0b:12f0::1]</a>
          <a href="http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80/index.html">http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80/index.html</a>
          <a href="https://[::ffff:192.0.2.128]">https://[::ffff:192.0.2.128]</a>
          <a href="http://[2001:db8:0:0:0:0:2:1]">http://[2001:db8:0:0:0:0:2:1]</a>
          <a href="https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/">https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/</a>
          <a href="http://[2001:db8:a0b:12f0::1/">http://[2001:db8:a0b:12f0::1/</a>
          <a href="http://[2001:db8:0:0:0:0:0:0:1]">http://[2001:db8:0:0:0:0:0:0:1]</a>
          <a href="https://[2001:db8::192.168.0.1]">https://[2001:db8::192.168.0.1]</a>
          <a href="http://[2001:db8:a0b:12f0:::1]">http://[2001:db8:a0b:12f0:::1]</a>
          <a href="ftp://[2001:db8:3333:4444:5555:6666:7777:8888:9999]">ftp://[2001:db8:3333:4444:5555:6666:7777:8888:9999]</a>
          <a href="http://[2001:db8:0000:0000:0000:0000:0000]">http://[2001:db8:0000:0000:0000:0000:0000]</a>
          <a href="https://[::1]:80000">https://[::1]:80000</a>
          <a href="http://[2001:db8::1::]">http://[2001:db8::1::]</a>
          <a href="https://[01.02.03.04]">https://[01.02.03.04]</a>
          <a href="http://[2001:db8:1234:5678:9abc:def0:1234]">http://[2001:db8:1234:5678:9abc:def0:1234]</a>
          <a href="https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334:3001]">https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334:3001]</a>
          <a href="http://[%32%30%30%31:%64%62%38::1234:567]:8080">http://[%32%30%30%31:%64%62%38::1234:567]:8080</a>
          <a href="http://[２００１:db８::1234:567]:8080">http://[２００１:db８::1234:567]:8080</a>
          <a href="http://[%32%30%30%31:db８::0x1234:0567]:8080">http://[%32%30%30%31:db８::0x1234:0567]:8080</a>

          [google](http://google.com)
          https://google.com

          This list has the following examples and some more:
          Too many segments
          Mixing IPv4 and IPv6 notation incorrectly
          Using too many colons
          Incomplete addresses
          Invalid port numbers
          Incorrect use of double colons
          Using IPv4 format within IPv6 brackets
          Missing segments
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected =
          <<~MARKDOWN
            Here are several examples of malformed IPv6 links in plain text, without any escaping or backticks:
            `<a href="http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]">http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]</a>`
            `<a href="http://[2001:db8::1234:5678]">http://[2001:db8::1234:5678]</a>`
            `<a href="https://[2001:db8::1234:5678]:8080">https://[2001:db8::1234:5678]:8080</a>`
            `<a href="http://[2001:db8::1234::567]8">http://[2001:db8::1234::567]8</a>`
            `<a href="ftp://[2001:db8:a0b:12f0::1]">ftp://[2001:db8:a0b:12f0::1]</a>`
            `<a href="http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80/index.html">http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80/index.html</a>`
            `<a href="https://[::ffff:192.0.2.128]">https://[::ffff:192.0.2.128]</a>`
            `<a href="http://[2001:db8:0:0:0:0:2:1]">http://[2001:db8:0:0:0:0:2:1]</a>`
            `<a href="https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/">https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/</a>`
            `<a href="http://[2001:db8:a0b:12f0::1/">http://[2001:db8:a0b:12f0::1/</a>`
            `<a href="http://[2001:db8:0:0:0:0:0:0:1]">http://[2001:db8:0:0:0:0:0:0:1]</a>`
            `<a href="https://[2001:db8::192.168.0.1]">https://[2001:db8::192.168.0.1]</a>`
            `<a href="http://[2001:db8:a0b:12f0:::1]">http://[2001:db8:a0b:12f0:::1]</a>`
            `<a href="ftp://[2001:db8:3333:4444:5555:6666:7777:8888:9999]">ftp://[2001:db8:3333:4444:5555:6666:7777:8888:9999]</a>`
            `<a href="http://[2001:db8:0000:0000:0000:0000:0000]">http://[2001:db8:0000:0000:0000:0000:0000]</a>`
            `<a href="https://[::1]:80000">https://[::1]:80000</a>`
            `<a href="http://[2001:db8::1::]">http://[2001:db8::1::]</a>`
            `<a href="https://[01.02.03.04]">https://[01.02.03.04]</a>`
            `<a href="http://[2001:db8:1234:5678:9abc:def0:1234]">http://[2001:db8:1234:5678:9abc:def0:1234]</a>`
            `<a href="https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334:3001]">https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334:3001]</a>`
            `<a href="http://[%32%30%30%31:%64%62%38::1234:567]:8080">http://[%32%30%30%31:%64%62%38::1234:567]:8080</a>`
            `<a href="http://[２００１:db８::1234:567]:8080">http://[２００１:db８::1234:567]:8080</a>`
            `<a href="http://[%32%30%30%31:db８::0x1234:0567]:8080">http://[%32%30%30%31:db８::0x1234:0567]:8080</a>`

            `[google](http://google.com)`
            `https://google.com`

            This list has the following examples and some more:
            Too many segments
            Mixing IPv4 and IPv6 notation incorrectly
            Using too many colons
            Incomplete addresses
            Invalid port numbers
            Incorrect use of double colons
            Using IPv4 format within IPv6 brackets
            Missing segments
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when standard plaintext URLs are invalid URLs' do
      let(:final_answer) do
        <<~MARKDOWN
          Here are a few examples of invalid URLs (Thank you Duo Chat for coming up with this list!)
          http:///example.com
          ://example.com
          http://exa mple.com
          http://example!.com
          http://example.com:65536  (port number too high)
          http://example.com:abc    (non-numeric port)
          http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334  (missing closing bracket)
          http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80]  (extra closing bracket)
          http://example.com/path%      (incomplete percent-encoding)
          http://example.com/path%2     (incomplete percent-encoding)
          http://example.com/path%0G    (invalid hex digit in percent-encoding)
          http://example.com/path\nquery  (newline in URL)
          http://example.com/path\tquery  (tab in URL)
          http://user:pass:word@example.com  (too many colons in userinfo)
          http://example.com/query?key=value&key2=value 2  (unescaped space in query)
          And some normal text after.

          Followed by a couple of actual URLs
          [Google Search](https://google.com)
          <a href="https://www.google.com">Google Search</a>
          <a href="https://www.google.com">Google Search</a>
          [Google Search](https://google.com)
          [Google Search](https://google.com)
          https://google.com
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            Here are a few examples of invalid URLs (Thank you Duo Chat for coming up with this list!)
            `http:///example.com`
            ://example.com
            `http://exa` mple.com
            `http://example`!.com
            `http://example.com:65536`  (port number too high)
            `http://example.com:`abc    (non-numeric port)
            `http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334`  (missing closing bracket)
            `http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80]`  (extra closing bracket)
            `http://example.com/path`%      (incomplete percent-encoding)
            `http://example.com/path`%2     (incomplete percent-encoding)
            `http://example.com/path`%0G    (invalid hex digit in percent-encoding)
            `http://example.com/path`\nquery  (newline in URL)
            `http://example.com/path`\tquery  (tab in URL)
            `http://user:pass:word@example.com`  (too many colons in userinfo)
            `http://example.com/query?key=value&key2=value` 2  (unescaped space in query)
            And some normal text after.

            Followed by a couple of actual URLs
            `[Google Search](https://google.com)`
            `<a href="https://www.google.com">Google Search</a>`
            `<a href="https://www.google.com">Google Search</a>`
            `[Google Search](https://google.com)`
            `[Google Search](https://google.com)`
            `https://google.com`
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when HTML URLs are invalid URLs' do
      let(:final_answer) do
        <<~MARKDOWN
          Here are a few examples of invalid URLs (Thank you Duo Chat for coming up with this list!)
          <a href="http:///example.com">http:///example.com</a>
          <a href="://example.com">://example.com</a>
          <a href="http://exa mple.com">http://exa mple.com</a>
          <a href="http://example!.com">http://example!.com</a>
          <a href="http://example.com:65536">http://example.com:65536</a>  (port number too high)
          <a href="http://example.com:abc">http://example.com:abc</a>    (non-numeric port)
          <a href="http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334">http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334</a>  (missing closing bracket)
          <a href="http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80]">http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80]</a>  (extra closing bracket)
          <a href="http://example.com/path%">http://example.com/path%</a>      (incomplete percent-encoding)
          <a href="http://example.com/path%2">http://example.com/path%2</a>     (incomplete percent-encoding)
          <a href="http://example.com/path%0G">http://example.com/path%0G</a>    (invalid hex digit in percent-encoding)
          <a href="http://example.com/path\nquery">http://example.com/path\nquery</a>  (newline in URL)
          <a href="http://example.com/path\tquery">http://example.com/path\tquery</a>  (tab in URL)
          <a href="http://user:pass:word@example.com">http://user:pass:word@example.com</a>  (too many colons in userinfo)
          <a href="http://example.com/query?key=value&key2=value 2">http://example.com/query?key=value&key2=value 2</a>  (unescaped space in query)
          And some normal text after.

          Followed by a couple of actual URLs
          [Google Search](https://google.com)
          <a href="https://www.google.com">Google Search</a>
          https://google.com
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            Here are a few examples of invalid URLs (Thank you Duo Chat for coming up with this list!)
            `<a href="http:///example.com">http:///example.com</a>`
            `<a href="://example.com">://example.com</a>`
            `<a href="http://exa mple.com">http://exa mple.com</a>`
            `<a href="http://example!.com">http://example!.com</a>`
            `<a href="http://example.com:65536">http://example.com:65536</a>`  (port number too high)
            `<a href="http://example.com:abc">http://example.com:abc</a>`    (non-numeric port)
            `<a href="http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334">http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334</a>`  (missing closing bracket)
            `<a href="http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80]">http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80]</a>`  (extra closing bracket)
            `<a href="http://example.com/path%">http://example.com/path%</a>`      (incomplete percent-encoding)
            `<a href="http://example.com/path%2">http://example.com/path%2</a>`     (incomplete percent-encoding)
            `<a href="http://example.com/path%0G">http://example.com/path%0G</a>`    (invalid hex digit in percent-encoding)
            `<a href="http://example.com/path\nquery">http://example.com/path\nquery</a>`  (newline in URL)
            `<a href="http://example.com/path\tquery">http://example.com/path\tquery</a>`  (tab in URL)
            `<a href="http://user:pass:word@example.com">http://user:pass:word@example.com</a>`  (too many colons in userinfo)
            `<a href="http://example.com/query?key=value&key2=value 2">http://example.com/query?key=value&key2=value 2</a>`  (unescaped space in query)
            And some normal text after.

            Followed by a couple of actual URLs
            `[Google Search](https://google.com)`
            `<a href="https://www.google.com">Google Search</a>`
            `https://google.com`
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when there is a complex mixture of escapes and backtick requirements' do
      let(:final_answer) do
        <<~MARKDOWN
          Certainly! I'll provide you with a variety of examples showing different ways to format links, both inside and outside of code blocks, with various levels of escaping. This will give you a comprehensive view of how links might appear when posted in a chat or markdown environment.

          1. Plain text links:
          	- https://www.gitlab.com
          	- http://example.com
          	- www.example.org
          2. Markdown formatted links:
          	- [GitLab](https://www.gitlab.com/)
          	- [Example Site](http://example.com/)
          	- [Relative link](http://gdk.test:3000/path/to/page)
          3. HTML formatted links:
          	- <a href="https://www.gitlab.com/">GitLab</a>
          	- <a href="http://example.com/">GitLab</a>
          4. Links inside code blocks:
          ```
          https://www.gitlab.com
          [GitLab](https://www.gitlab.com)
          <a href="https://www.gitlab.com">GitLab</a>

          ```
          5. Escaped links inside code blocks:
          ```
          https:\/\/www.gitlab.com
          \[GitLab\]\(https:\/\/www.gitlab.com\)
          \<a href=\"https:\/\/www.gitlab.com\"\>GitLab\<\/a\>

          ```
          6. Partially escaped links:
          	- \[GitLab](https://www.gitlab.com)
          	- [GitLab\](https://www.gitlab.com)
          	- GitLab
          7. Links with special characters:
          	- https://example.com/path?param1=value1&param2=value2
          	- [Complex Markdown Link](https://example.com/path?param1=value1&param2=value2#section)
            - <a href="https://example.com/path?param1=value1&param2=value2#section">Complex HTML Link</a>
          8. Links in nested structures:
          	- List with links:
          		- [GitLab](https://www.gitlab.com)
          		- <a href="https://example.com/path?param1=value1&param2=value2#section">Example Link</a>
          9. Code blocks with mixed content:
          ```
          Regular link: https://www.gitlab.com
          Markdown link: [GitLab](https://www.gitlab.com)
          Escaped link: https:\/\/www.gitlab.com
          Partially escaped: \[GitLab](https://www.gitlab.com)
          HTML link: <a href="https://www.gitlab.com">GitLab</a>

          ```
          10. Links with unusual protocols:
          	- ftp://ftp.example.com
          	- mailto:user@example.com
          	- tel:+1234567890
          11. Links with IP addresses:
          	- http://192.168.1.1
          	- https://[2001:db8::1]
          12. Links with port numbers:
          	- http://localhosts:8080
          	- https://example.com:443

          These examples cover a wide range of possibilities for how someone might try to post a URL or link in a chat environment. The appearance and functionality of these links may vary depending on the specific chat or markdown renderer being used.

          Sources: Clean: Testing The View Summary Button Prompt Injection

          Your feedback is valuable to us. Please let us know if you have any questions or if there's anything else you'd like to know about formatting links or any other topic!
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            Certainly! I'll provide you with a variety of examples showing different ways to format links, both inside and outside of code blocks, with various levels of escaping. This will give you a comprehensive view of how links might appear when posted in a chat or markdown environment.

            1. Plain text links:
            	- `https://www.gitlab.com`
            	- `http://example.com`
            	- `www.example.org`
            2. Markdown formatted links:
            	- `[GitLab](https://www.gitlab.com/)`
            	- `[Example Site](http://example.com/)`
            	- `[Relative link](http://gdk.test:3000/path/to/page)`
            3. HTML formatted links:
            	- `<a href="https://www.gitlab.com/">GitLab</a>`
            	- `<a href="http://example.com/">GitLab</a>`
            4. Links inside code blocks:
            ```
            https://www.gitlab.com
            [GitLab](https://www.gitlab.com)
            <a href="https://www.gitlab.com">GitLab</a>

            ```
            5. Escaped links inside code blocks:
            ```
            https:\/\/www.gitlab.com
            \[GitLab\]\(https:\/\/www.gitlab.com\)
            \<a href=\"https:\/\/www.gitlab.com\"\>GitLab\<\/a\>

            ```
            6. Partially escaped links:
            	- \`[GitLab](https://www.gitlab.com)`
            	- `[GitLab\](https://www.gitlab.com)`
            	- GitLab
            7. Links with special characters:
            	- `https://example.com/path?param1=value1&param2=value2`
            	- `[Complex Markdown Link](https://example.com/path?param1=value1&param2=value2#section)`
              - `<a href="https://example.com/path?param1=value1&param2=value2#section">Complex HTML Link</a>`
            8. Links in nested structures:
            	- List with links:
            		- `[GitLab](https://www.gitlab.com)`
            		- `<a href="https://example.com/path?param1=value1&param2=value2#section">Example Link</a>`
            9. Code blocks with mixed content:
            ```
            Regular link: https://www.gitlab.com
            Markdown link: [GitLab](https://www.gitlab.com)
            Escaped link: https:\/\/www.gitlab.com
            Partially escaped: \[GitLab](https://www.gitlab.com)
            HTML link: <a href="https://www.gitlab.com">GitLab</a>

            ```
            10. Links with unusual protocols:
            	- `ftp://ftp.example.com`
            	- `mailto:user@example.com`
            	- `tel:+1234567890`
            11. Links with IP addresses:
            	- `http://192.168.1.1`
            	- `https://[2001:db8::1]`
            12. Links with port numbers:
            	- `http://localhosts:8080`
            	- `https://example.com:443`

            These examples cover a wide range of possibilities for how someone might try to post a URL or link in a chat environment. The appearance and functionality of these links may vary depending on the specific chat or markdown renderer being used.

            Sources: Clean: Testing The View Summary Button Prompt Injection

            Your feedback is valuable to us. Please let us know if you have any questions or if there's anything else you'd like to know about formatting links or any other topic!
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when markdown URLs are invalid URLs' do
      let(:final_answer) do
        <<~MARKDOWN
          Here are a few examples of invalid Markdown URLs
          [http:///example.com](http:///example.com)
          [://example.com](://example.com)
          [http://exa mple.com](http://exa mple.com)
          [http://example!.com](http://example!.com)
          [http://example.com:65536](http://example.com:65536)  (port number too high)
          [http://example.com:abc](http://example.com:abc)    (non-numeric port)
          [http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334](http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334)  (missing closing bracket)
          [http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80]](http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80])  (extra closing bracket)
          [http://example.com/path%](http://example.com/path%)      (incomplete percent-encoding)
          [http://example.com/path%2](http://example.com/path%2)     (incomplete percent-encoding)
          [http://example.com/path%0G](http://example.com/path%0G)    (invalid hex digit in percent-encoding)
          [http://example.com/path\nquery](http://example.com/path\nquery)  (newline in URL)
          [http://example.com/path\tquery](http://example.com/path\tquery)  (tab in URL)
          [http://user:pass:word@example.com](http://user:pass:word@example.com)  (too many colons in userinfo)
          [http://example.com/query?key=value&key2=value 2](http://example.com/query?key=value&key2=value 2)  (unescaped space in query)

          https://google.com
          http:www.testing.com
          [Google Search](https://google.com)
        MARKDOWN
      end

      it 'sanitizes URLs correctly' do
        expected =
          <<~MARKDOWN
            Here are a few examples of invalid Markdown URLs
            `[http:///example.com](http:///example.com)`
            `[://example.com](://example.com)`
            `[http://exa mple.com](http://exa mple.com)`
            `[http://example!.com](http://example!.com)`
            `[http://example.com:65536](http://example.com:65536)`  (port number too high)
            `[http://example.com:abc](http://example.com:abc)`    (non-numeric port)
            `[http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334](http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334)`  (missing closing bracket)
            `[http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80]](http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80])`  (extra closing bracket)
            `[http://example.com/path%](http://example.com/path%)`      (incomplete percent-encoding)
            `[http://example.com/path%2](http://example.com/path%2)`     (incomplete percent-encoding)
            `[http://example.com/path%0G](http://example.com/path%0G)`    (invalid hex digit in percent-encoding)
            `[http://example.com/path\nquery](http://example.com/path\nquery)`  (newline in URL)
            `[http://example.com/path\tquery](http://example.com/path\tquery)`  (tab in URL)
            `[http://user:pass:word@example.com](http://user:pass:word@example.com)`  (too many colons in userinfo)
            `[http://example.com/query?key=value&key2=value 2](http://example.com/query?key=value&key2=value 2)`  (unescaped space in query)

            `https://google.com`
            `http:www.testing.com`
            `[Google Search](https://google.com)`
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when markdown URLs are different types of malformed IPv6 URLs' do
      let(:final_answer) do
        <<~MARKDOWN
          Here are several examples of malformed IPv6 links in markdown formatting, without any escaping or backticks:
          [http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]](http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334])
          [http://[2001:db8::1234:5678]](http://[2001:db8::1234:5678])
          [https://[2001:db8::1234:5678]:8080](https://[2001:db8::1234:5678]:8080)
          [http://[2001:db8::1234::567]8](http://[2001:db8::1234::567]8)
          [ftp://[2001:db8:a0b:12f0::1]](ftp://[2001:db8:a0b:12f0::1])
          [http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80/index.html](http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80/index.html)
          [https://[::ffff:192.0.2.128]](https://[::ffff:192.0.2.128])
          [http://[2001:db8:0:0:0:0:2:1]](http://[2001:db8:0:0:0:0:2:1])
          [https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/](https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/)
          [http://[2001:db8:a0b:12f0::1/](http://[2001:db8:a0b:12f0::1/)
          [http://[2001:db8:0:0:0:0:0:0:1]](http://[2001:db8:0:0:0:0:0:0:1])
          [https://[2001:db8::192.168.0.1]](https://[2001:db8::192.168.0.1])
          [http://[2001:db8:a0b:12f0:::1]](http://[2001:db8:a0b:12f0:::1])
          [ftp://[2001:db8:3333:4444:5555:6666:7777:8888:9999]](ftp://[2001:db8:3333:4444:5555:6666:7777:8888:9999])
          [http://[2001:db8:0000:0000:0000:0000:0000]](http://[2001:db8:0000:0000:0000:0000:0000])
          [https://[::1]:80000](https://[::1]:80000)
          [http://[2001:db8::1::]](http://[2001:db8::1::])
          [https://[01.02.03.04]](https://[01.02.03.04])
          [http://[2001:db8:1234:5678:9abc:def0:1234]](http://[2001:db8:1234:5678:9abc:def0:1234])
          [https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334:3001]](https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334:3001])
          [http://[%32%30%30%31:%64%62%38::1234:567]:8080](http://[%32%30%30%31:%64%62%38::1234:567]:8080)
          [http://[２００１:db８::1234:567]:8080](http://[２００１:db８::1234:567]:8080)
          [http://[%32%30%30%31:db８::0x1234:0567]:8080](http://[%32%30%30%31:db８::0x1234:0567]:8080)

          <a href="https://www.google.com">Google Search</a>
          https://www.google.com
          [google](https://google.com)
          https://testinglink.com
          https://google.com

          This list has the following examples and some more:
          Too many segments
          Mixing IPv4 and IPv6 notation incorrectly
          Using too many colons
          Incomplete addresses
          Invalid port numbers
          Incorrect use of double colons
          Using IPv4 format within IPv6 brackets
          Missing segments
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected =
          <<~MARKDOWN
            Here are several examples of malformed IPv6 links in markdown formatting, without any escaping or backticks:
            `[http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]](http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334])`
            `[http://[2001:db8::1234:5678]](http://[2001:db8::1234:5678])`
            `[https://[2001:db8::1234:5678]:8080](https://[2001:db8::1234:5678]:8080)`
            `[http://[2001:db8::1234::567]8](http://[2001:db8::1234::567]8)`
            `[ftp://[2001:db8:a0b:12f0::1]](ftp://[2001:db8:a0b:12f0::1])`
            `[http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80/index.html](http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:80/index.html)`
            `[https://[::ffff:192.0.2.128]](https://[::ffff:192.0.2.128])`
            `[http://[2001:db8:0:0:0:0:2:1]](http://[2001:db8:0:0:0:0:2:1])`
            `[https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/](https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/)`
            `[http://[2001:db8:a0b:12f0::1/](http://[2001:db8:a0b:12f0::1/)`
            `[http://[2001:db8:0:0:0:0:0:0:1]](http://[2001:db8:0:0:0:0:0:0:1])`
            `[https://[2001:db8::192.168.0.1]](https://[2001:db8::192.168.0.1])`
            `[http://[2001:db8:a0b:12f0:::1]](http://[2001:db8:a0b:12f0:::1])`
            `[ftp://[2001:db8:3333:4444:5555:6666:7777:8888:9999]](ftp://[2001:db8:3333:4444:5555:6666:7777:8888:9999])`
            `[http://[2001:db8:0000:0000:0000:0000:0000]](http://[2001:db8:0000:0000:0000:0000:0000])`
            `[https://[::1]:80000](https://[::1]:80000)`
            `[http://[2001:db8::1::]](http://[2001:db8::1::])`
            `[https://[01.02.03.04]](https://[01.02.03.04])`
            `[http://[2001:db8:1234:5678:9abc:def0:1234]](http://[2001:db8:1234:5678:9abc:def0:1234])`
            `[https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334:3001]](https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334:3001])`
            `[http://[%32%30%30%31:%64%62%38::1234:567]:8080](http://[%32%30%30%31:%64%62%38::1234:567]:8080)`
            `[http://[２００１:db８::1234:567]:8080](http://[２００１:db８::1234:567]:8080)`
            `[http://[%32%30%30%31:db８::0x1234:0567]:8080](http://[%32%30%30%31:db８::0x1234:0567]:8080)`

            `<a href="https://www.google.com">Google Search</a>`
            `https://www.google.com`
            `[google](https://google.com)`
            `https://testinglink.com`
            `https://google.com`

            This list has the following examples and some more:
            Too many segments
            Mixing IPv4 and IPv6 notation incorrectly
            Using too many colons
            Incomplete addresses
            Invalid port numbers
            Incorrect use of double colons
            Using IPv4 format within IPv6 brackets
            Missing segments
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when there are multiple lines and code blocks with complex escapes' do
      let(:final_answer) do
        <<~MARKDOWN
          When not in a code block, the text:

          ```ruby
           Partially escaped Markdown link: \\` \\` \\``[GitLab](https://www.gitlab.com)
          ```

          would look like this:

          `\[GitLab](https://www.gitlab.com) followed by \\\``google and another normal link https://testing.com
          Partially escaped Markdown link: \` \` \```[GitLab](https://www.gitlab.com)

          [GitLab](https://www.google.com)

          Here's an explanation of how it's rendered:

          1. "Partially escaped Markdown link:" appears as plain text.
          2. The first two `\\`` sequences are rendered as `\`` (a backslash followed by a backtick).
          3. The third `\\``` sequence is rendered as `\```, which starts an inline code block.
          4. `[GitLab](https://www.gitlab.com)` appears as plain text within the inline code block.
          5. The final backtick (`) closes the inline code block.

          This demonstrates how backslashes can be used to escape special characters in Markdown, and how backticks can create inline code blocks of varying lengths.

          While this formatting question isn't directly related to the issue you're currently viewing ("Clean: Testing The View Summary Button Prompt Injection"), understanding Markdown can be helpful when working with GitLab issues and comments. If you have any questions about how this relates to the current issue or Markdown usage in GitLab, please feel free to ask.

          Your feedback on this explanation would be appreciated. How did I do in answering your question about Markdown formatting?
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected =
          <<~MARKDOWN
            When not in a code block, the text:

            ```ruby
             Partially escaped Markdown link: \\` \\` \\``[GitLab](https://www.gitlab.com)
            ```

            would look like this:

            `\[GitLab](https://www.gitlab.com)` followed by \\\ ` `google and another normal link `https://testing.com`
            Partially escaped Markdown link: ` ` ` ` `[GitLab](https://www.gitlab.com)`

            `[GitLab](https://www.google.com)`

            Here's an explanation of how it's rendered:

            1. "Partially escaped Markdown link:" appears as plain text.
            2. The first two `\\ ` ` sequences are rendered as ` ` ` (a backslash followed by a backtick).
            3. The third `\\ ` ` ` sequence is rendered as ` ` ` `, which starts an inline code block.
            4. `[GitLab](https://www.gitlab.com)` appears as plain text within the inline code block.
            5. The final backtick (`) closes the inline code block.

            This demonstrates how backslashes can be used to escape special characters in Markdown, and how backticks can create inline code blocks of varying lengths.

            While this formatting question isn't directly related to the issue you're currently viewing ("Clean: Testing The View Summary Button Prompt Injection"), understanding Markdown can be helpful when working with GitLab issues and comments. If you have any questions about how this relates to the current issue or Markdown usage in GitLab, please feel free to ask.

            Your feedback on this explanation would be appreciated. How did I do in answering your question about Markdown formatting?
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end

    context 'when there is a only a code block in the answer' do
      let(:final_answer) do
        <<~MARKDOWN
          ```ruby
            async function fetchUserData(userId) {
              try {
                const response = await fetch(`https://api.example.com/users/${userId}`);
                if (!response.ok) {
                  throw new Error('Network response was not ok');
                }
                const userData = await response.json();
                return userData;
              } catch (error) {
                console.error('Error fetching user data:', error);
                return null;
              }
            }

            function displayUserInfo(userData) {
              if (userData) {
                console.log(`Name: ${userData.name}`);
                console.log(`Email: ${userData.email}`);
                console.log(`Age: ${userData.age}`);
              } else {
                console.log('User data not available');
              }
            }

            (async () => {
              const userId = 123;
              const user = await fetchUserData(userId);
              displayUserInfo(user);
            })();
          ```
        MARKDOWN
      end

      it 'sanitizes the URLs correctly' do
        expected =
          <<~MARKDOWN
            ```ruby
              async function fetchUserData(userId) {
                try {
                  const response = await fetch(`https://api.example.com/users/${userId}`);
                  if (!response.ok) {
                    throw new Error('Network response was not ok');
                  }
                  const userData = await response.json();
                  return userData;
                } catch (error) {
                  console.error('Error fetching user data:', error);
                  return null;
                }
              }

              function displayUserInfo(userData) {
                if (userData) {
                  console.log(`Name: ${userData.name}`);
                  console.log(`Email: ${userData.email}`);
                  console.log(`Age: ${userData.age}`);
                } else {
                  console.log('User data not available');
                }
              }

              (async () => {
                const userId = 123;
                const user = await fetchUserData(userId);
                displayUserInfo(user);
              })();
            ```
          MARKDOWN

        expect(sanitized_answer).to eq(expected)
      end
    end
  end
end
