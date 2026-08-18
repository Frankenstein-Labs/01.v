# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Packages::Pypi::Upstream::Configuration, feature_category: :package_registry do
  describe '.extract_coordinates' do
    where(:filename, :expected) do
      [
        ['requests-2.31.0.tar.gz', %w[requests 2.31.0]],
        ['requests-2.31.0-py3-none-any.whl', %w[requests 2.31.0]],
        ['django-allauth-0.1.tar.gz', %w[django-allauth 0.1]],
        ['SQLAlchemy-2.0.30.tar.gz', %w[sqlalchemy 2.0.30]],
        ['zope.interface-8.4.1a1.tar.gz', %w[zope-interface 8.4.1a1]],
        ['typing_extensions-4.12.2.tar.gz', %w[typing-extensions 4.12.2]],
        # Names ending in a numeric or "v"-prefixed segment: the split is the last
        # "-", not the first one whose remainder happens to parse as a version.
        ['flake8_2020-1.7.0.tar.gz', %w[flake8-2020 1.7.0]],
        ['pytest_flake8_v2-1.4.4.tar.gz', %w[pytest-flake8-v2 1.4.4]],
        # PEP 427 build tag sits after the version, so field 1 is still the version.
        ['foo-1.0-1-py3-none-any.whl', %w[foo 1.0]],
        # PEP 625 escaped "-" out of sdist names only for uploads since it was
        # enforced, so the back catalogue still has a "-" inside the version. The
        # rightmost split lands in the version; the scan has to keep walking left.
        ['mercurial-3.3-rc.tar.gz', %w[mercurial 3.3-rc]],
        ['GitPython-2.1.0-beta1.tar.gz', %w[gitpython 2.1.0-beta1]],
        ['docutils-0.15.1-post1.tar.gz', %w[docutils 0.15.1-post1]],
        ['Pillow-3.1.0-rc1.tar.gz', %w[pillow 3.1.0-rc1]],
        ['email_validator-0.1.0-rc1.tar.gz', %w[email-validator 0.1.0-rc1]],
        ['requests-2.31.0.txt', nil],
        ['not-a-package.tar.gz', nil],
        ['-1.0.tar.gz', nil],
        ['', nil]
      ]
    end

    with_them do
      it { expect(described_class.extract_coordinates(filename)).to eq(expected) }
    end
  end

  describe '.normalize_name' do
    where(:package_name, :expected) do
      [
        ['Requests', 'requests'],
        ['zope.interface', 'zope-interface'],
        ['typing_extensions', 'typing-extensions'],
        ['requests-2', 'requests-2']
      ]
    end

    with_them do
      it { expect(described_class.normalize_name(package_name)).to eq(expected) }
    end
  end

  describe '.enforced_coordinates' do
    let(:path) { 'files.pythonhosted.org/packages/aa/requests-2.31.0.tar.gz' }

    it 'returns the filename-derived coordinates when the claimed name agrees' do
      expect(described_class.enforced_coordinates(path, claimed_name: 'Requests'))
        .to eq(%w[requests 2.31.0])
    end

    it 'strips a .metadata suffix before splitting' do
      expect(described_class.enforced_coordinates("#{path}.metadata", claimed_name: 'requests'))
        .to eq(%w[requests 2.31.0])
    end

    # The caller cannot move the split by claiming a longer name.
    where(:description, :claimed_name) do
      [
        ['one segment swallowed', 'requests-2'],
        ['two segments swallowed', 'requests-2-31'],
        ['an unrelated name', 'urllib3']
      ]
    end

    with_them do
      it 'returns nil when the claimed name disagrees with the filename' do
        expect(described_class.enforced_coordinates(path, claimed_name: claimed_name)).to be_nil
      end
    end

    it 'returns nil when no version can be derived' do
      expect(described_class.enforced_coordinates('files.pythonhosted.org/aa/notes.txt', claimed_name: 'notes'))
        .to be_nil
    end
  end

  describe '.file_url_for' do
    let(:artifact) { 'packages/ba/bb/dfa0141a32d7/requests-2.31.0.tar.gz' }

    it 'rebuilds the https URL when the leading segment is an allowed host' do
      expect(described_class.file_url_for("files.pythonhosted.org/#{artifact}"))
        .to eq("https://files.pythonhosted.org/#{artifact}")
    end

    it 'emits the host in canonical case rather than as received' do
      expect(described_class.file_url_for("FILES.PythonHosted.ORG/#{artifact}"))
        .to eq("https://files.pythonhosted.org/#{artifact}")
    end

    it 'preserves the case of the artifact path itself' do
      expect(described_class.file_url_for('files.pythonhosted.org/packages/aa/SQLAlchemy-2.0.30.tar.gz'))
        .to eq('https://files.pythonhosted.org/packages/aa/SQLAlchemy-2.0.30.tar.gz')
    end

    context 'when the leading segment is not an allowed host' do
      where(:description, :path) do
        [
          ['a host the rewrite captured but we do not trust', 'cdn.example.net/packages/aa/requests-2.31.0.tar.gz'],
          ['a lookalike suffix', 'evil-files.pythonhosted.org/packages/aa/requests-2.31.0.tar.gz'],
          ['a lookalike subdomain', 'files.pythonhosted.org.evil.net/packages/aa/requests-2.31.0.tar.gz'],
          ['the allowed host as a later segment', 'evil.net/files.pythonhosted.org/requests-2.31.0.tar.gz'],
          ['the host with no artifact path after it', 'files.pythonhosted.org'],
          ['a bare trailing slash after the host', 'files.pythonhosted.org/'],
          ['a parent-directory segment', 'files.pythonhosted.org/../../etc/passwd'],
          ['a current-directory segment', 'files.pythonhosted.org/./packages/aa/requests-2.31.0.tar.gz'],
          ['traversal in the host position', '../files.pythonhosted.org/packages/aa/requests-2.31.0.tar.gz']
        ]
      end

      with_them do
        it 'returns nil so the caller fails closed' do
          expect(described_class.file_url_for(path)).to be_nil
        end
      end
    end

    context 'with paths that would let the fetched artifact diverge from the enforced version' do
      where(:description, :path) do
        [
          ['a fragment truncating the URL client-side',
            'files.pythonhosted.org/aa/requests-2.31.0.tar.gz#x-9.9.9.tar.gz'],
          ['a query string truncating the URL client-side',
            'files.pythonhosted.org/aa/requests-2.31.0.tar.gz?x-9.9.9.tar.gz'],
          ['a percent escape that could re-decode', 'files.pythonhosted.org/aa/requests-2.31.0.tar.gz%23x.tar.gz'],
          ['a backslash some clients fold to a slash', 'files.pythonhosted.org\\aa\\requests-2.31.0.tar.gz'],
          ['whitespace', 'files.pythonhosted.org/aa/requests 2.31.0.tar.gz'],
          ['a CRLF sequence', "files.pythonhosted.org/aa/requests-2.31.0.tar.gz\r\nX-Injected: 1"],
          ['a leading slash', '/files.pythonhosted.org/aa/requests-2.31.0.tar.gz'],
          ['an empty segment', 'files.pythonhosted.org//requests-2.31.0.tar.gz'],
          ['an empty path', ''],
          ['a nil path', nil]
        ]
      end

      with_them do
        it 'returns nil so the caller fails closed' do
          expect(described_class.file_url_for(path)).to be_nil
        end
      end
    end
  end

  describe '.escaped_name' do
    where(:package_name, :normalized) do
      [
        ['Requests', 'requests'],
        ['Flask', 'flask'],
        ['zope.interface', 'zope-interface'],
        ['typing_extensions', 'typing-extensions']
      ]
    end

    with_them do
      it 'PEP 503-normalizes the name' do
        expect(described_class.escaped_name(package_name)).to eq(normalized)
      end
    end

    # Normalization collapses [-_.] and downcases; it does not remove anything
    # else, so a name off the glob route can still carry URL metacharacters.
    context 'with a name carrying URL metacharacters' do
      where(:package_name, :escaped) do
        [
          ['evil?x', 'evil%3Fx'],
          ['evil#x', 'evil%23x'],
          ['evil/x', 'evil%2Fx'],
          ['evil x', 'evil%20x'],
          ['evil?x#y', 'evil%3Fx%23y']
        ]
      end

      with_them do
        it 'escapes them rather than letting them change the URL structure' do
          expect(described_class.escaped_name(package_name)).to eq(escaped)
        end
      end
    end
  end
end
