# frozen_string_literal: true

module Packages
  module Pypi
    module Upstream
      # EE-only: builds upstream PyPI URLs and derives coordinates from PyPI
      # filenames. Used solely from the FF-gated EE prepend (EE::API::PypiPackages).
      class Configuration
        # Prefixes the Workhorse transform matches when rewriting file URLs in the
        # upstream index. Matching on the scheme alone routes *every* entry back
        # through GitLab, including one pointing somewhere other than PyPI's CDN --
        # which is then rejected at download time against ALLOWED_FILE_HOSTS. Matching
        # the full host instead would leave such an entry unrewritten and pip would
        # fetch it directly, with the Dependency Firewall never seeing the download.
        #
        # Workhorse also matches the `http://` spelling of this prefix, so an entry
        # served over http cannot slip past unrewritten. That matters because the
        # presenter this replaced dropped such entries outright (it required
        # `scheme == 'https'` before emitting a file), so matching https alone would
        # be a regression rather than a pre-existing gap. Matching is
        # case-insensitive.
        #
        # The scheme is deliberately not carried into the forward path: `file_url_for`
        # rebuilds every upstream URL over https, so an `http` entry is fetched over
        # TLS or not at all.
        URL_SCHEME = 'https://'

        # Hosts a forwarded download may redirect to. The rewrite above encodes the
        # upstream host as the first segment of the forward path, so it arrives here as
        # client input and is matched exactly against this list rather than trusted.
        ALLOWED_FILE_HOSTS = %w[files.pythonhosted.org].freeze

        EXTENSION_REGEX = /\.(?:tar\.(?:gz|bz2|xz|z)|tgz|zip|whl|egg)\z/i

        # A plain upstream artifact path: one or more `/`-joined segments of
        # unreserved URL characters. `#`, `?`, `%`, backslash and whitespace are
        # excluded deliberately -- an HTTP client would strip or reinterpret them, see
        # `file_url_for`. `+`, `~` and `!` are allowed because PEP 440 local versions
        # and epochs can produce them.
        #
        # This covers everything seen in real pypi.org paths except `,`, which appears
        # on a handful of malformed wheel tags (36 awswrangler files such as
        # `awswrangler-0.0b0-py27,py36,py37-none-any.whl`). Those reach here intact --
        # the Workhorse rewrite only swaps the scheme prefix and `,` is a legal
        # unencoded path character -- and `file_url_for` returns nil for them. No
        # behaviour change is needed: the tag matches no supported Python, so pip
        # skips those wheels regardless.
        SAFE_FILE_PATH_REGEX = %r{\A[A-Za-z0-9][A-Za-z0-9._+~!-]*(?:/[A-Za-z0-9._+~!-]+)*\z}

        # PEP 503 normalization only downcases and collapses runs of [-_.], so it
        # leaves anything else a caller put in the name -- `?`, `#`, `/`, spaces --
        # intact. The name arrives from the `simple/*package_name` glob route, so it
        # is escaped before being interpolated into a URL, both for the upstream
        # request and for the prefix every rewritten file URL is built from. Real
        # names normalize to [a-z0-9-], which url_encode leaves untouched.
        def self.escaped_name(package_name)
          ERB::Util.url_encode(normalize_name(package_name))
        end

        # Builds the upstream artifact URL from a client-supplied "<host>/<path>", or
        # returns nil when that is not a plain artifact path on an allowed host. The
        # host is re-emitted from the validated match, never interpolated as received.
        #
        # The same value is both the redirect target and the source of the version the
        # Dependency Firewall enforces on, so the two must not be able to disagree.
        # Grape decodes route params, so a caller sending `%23` lands a literal `#`
        # here: `foo-1.0.tar.gz%23x-9.9.9.tar.gz` would be enforced as version
        # "1.0.tar.gz#x" while the client, stripping the fragment, fetches the real
        # `foo-1.0.tar.gz`. Validating here rather than at the call site keeps the
        # check inseparable from the URL construction it protects. `?` truncates the
        # same way; conforming clients strip both before they ever reach us, so a
        # genuine request cannot contain either.
        def self.file_url_for(upstream_path)
          path = upstream_path.to_s
          return unless path.match?(SAFE_FILE_PATH_REGEX)

          segments = path.split('/')
          # SAFE_FILE_PATH_REGEX allows "." and "..", so reject traversal here
          # rather than leaning on the route's file_path validator: this method
          # is meant to hold on its own.
          return if segments.any? { |segment| segment == '.' || segment == '..' }

          host, _, rest = path.partition('/')
          return if rest.empty?

          host = host.downcase
          return unless ALLOWED_FILE_HOSTS.include?(host)

          "#{URL_SCHEME}#{host}/#{rest}"
        end

        def self.normalize_name(package_name)
          ::Sbom::PackageUrl::Normalizer.new(type: 'pypi', text: package_name.to_s).normalize_name
        end

        # The [name, version] the Dependency Firewall should enforce on for a
        # forwarded download, or nil when the request should fail closed.
        #
        # Both coordinates come from the filename, never from `claimed_name`: that is
        # a free-form route segment, and letting it choose where the version starts
        # would let a caller shift the split (`requests-2` turns requests 2.31.0 into
        # version "31.0", which matches no advisory).
        #
        # The equality check is a consistency guard, not the control that stops
        # shifting. `claimed_name` is caller-supplied, so anyone can echo back
        # whatever name the filename yields and pass it. That only matters where the
        # sdist base carries a dash of its own and the rightmost split lands inside
        # the version -- `aiohttp-2.0.6-1.tar.gz` claimed as "aiohttp-2.0.6" is
        # enforced as ("aiohttp-2-0-6", "1"), a name no advisory mentions. An honest
        # caller 404s on those same files, so it is only reachable deliberately.
        # Closing it needs the forward URL to be unforgeable rather than a name the
        # caller pairs with an arbitrary artifact path, tracked in
        # https://gitlab.com/gitlab-org/gitlab/-/work_items/608136.
        #
        # `.metadata` (PEP 658) is stripped before the split.
        def self.enforced_coordinates(upstream_path, claimed_name:)
          filename = upstream_path.to_s.split('/').last.to_s.delete_suffix('.metadata')

          name, version = extract_coordinates(filename)
          return if version.blank?
          return unless name == normalize_name(claimed_name)

          [name, version]
        end

        # Splits a PyPI artifact filename into its [normalized name, version], or
        # returns nil when it is not a recognisable artifact filename.
        #
        # The split comes from the filename's own layout, never from a caller-supplied
        # name, so a caller cannot choose where the version starts. Reading
        # `requests-2.31.0.tar.gz` as package "requests-2" would otherwise yield version
        # "31.0", which matches no advisory, and the firewall would wave through a
        # download of the genuine requests 2.31.0.
        def self.extract_coordinates(filename)
          base = filename.to_s
          return unless base.match?(EXTENSION_REGEX)

          wheel = base.match?(/\.(?:whl|egg)\z/i)
          base = base.sub(EXTENSION_REGEX, '')

          # PEP 427 fixes the wheel layout as <name>-<version>[-<build>]-<py>-<abi>-<plat>,
          # so field 1 is the version. Searching for the shortest prefix that parses as a
          # version instead would mis-split any name ending in a numeric or "v"-prefixed
          # segment -- `flake8_2020-1.7.0.tar.gz` would read as ("flake8", "2020").
          name, version = wheel ? base.split('-', 3).first(2) : sdist_split(base)
          return if name.blank? || version.blank?
          return unless version.match?(::Gitlab::Regex.pypi_version_regex)

          [normalize_name(name), version]
        end

        # Walks the "-" boundaries right to left and stops at the first split whose
        # remainder parses as a version. Stopping at the rightmost one keeps the split
        # out of a caller's reach. PEP 625 escapes "-" out of both fields, but only for
        # uploads since it was enforced -- the back catalogue still has versions like
        # Pillow's "3.1.0-rc1", where the last "-" sits inside the version and a plain
        # rpartition would 404 the file.
        def self.sdist_split(base)
          idx = base.length

          # The `idx > 0` guard matters: String#rindex reads a negative start as an
          # offset from the end, so without it a leading "-" restarts the search and
          # the loop spins.
          while idx > 0
            idx = base.rindex('-', idx - 1)
            break if idx.nil?

            version = base[(idx + 1)..]
            return [base[0...idx], version] if version.match?(::Gitlab::Regex.pypi_version_regex)
          end

          nil
        end
        private_class_method :sdist_split
      end
    end
  end
end
