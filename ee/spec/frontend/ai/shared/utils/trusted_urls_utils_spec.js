import { computeTrustedUrls } from 'ee/ai/shared/utils/trusted_urls_utils';

describe('computeTrustedUrls', () => {
  beforeEach(() => {
    window.gon = {};
  });

  afterEach(() => {
    delete window.gon;
  });

  it('includes gitlab.com and docs URL by default', () => {
    const result = computeTrustedUrls();
    expect(result).toContain('gitlab.com');
    expect(result).toContain('docs.gitlab.com');
  });

  it('includes the current GitLab instance hostname when gon.gitlab_url is set', () => {
    window.gon.gitlab_url = 'https://gitlab.example.com';
    const result = computeTrustedUrls();
    expect(result).toContain('gitlab.example.com');
  });

  it('includes additional URLs passed as parameter', () => {
    const result = computeTrustedUrls(['example.com', 'custom.org']);
    expect(result).toContain('example.com');
    expect(result).toContain('custom.org');
  });

  it('removes duplicate URLs', () => {
    const result = computeTrustedUrls(['gitlab.com', 'https://gitlab.com/path']);
    const gitlabComCount = result.filter((url) => url === 'gitlab.com').length;
    expect(gitlabComCount).toBe(1);
  });

  it('returns an array of unique hostnames', () => {
    window.gon.gitlab_url = 'https://gitlab.example.com';
    const result = computeTrustedUrls(['https://example.com']);
    expect(Array.isArray(result)).toBe(true);
    expect(new Set(result).size).toBe(result.length);
  });
});
