import { updateDocumentTitle } from 'ee/packages_and_registries/virtual_registries/pages/container/utils';

describe('updateDocumentTitle', () => {
  const originalTitle = 'Virtual registry';
  const updateTitle = updateDocumentTitle(originalTitle);

  it('sets document title to initial title when no matched routes have meta.text', () => {
    const to = {
      matched: [{ meta: {} }, { meta: {} }],
    };

    updateTitle(to);

    expect(document.title).toBe(originalTitle);
  });

  it('sets document title with single route meta.text', () => {
    const to = {
      matched: [{ meta: { text: 'Packages' } }],
    };

    updateTitle(to);

    expect(document.title).toBe(`Packages · ${originalTitle}`);
  });

  it('sets document title with multiple route meta.text values', () => {
    const to = {
      matched: [{ meta: { text: 'Virtual Registries' } }, { meta: { text: 'Container' } }],
    };

    updateTitle(to);

    expect(document.title).toBe(`Container · Virtual Registries · ${originalTitle}`);
  });

  it('skips routes without meta.text and includes only routes with meta.text', () => {
    const to = {
      matched: [
        { meta: { text: 'Virtual Registries' } },
        { meta: {} },
        { meta: { text: 'Container' } },
      ],
    };

    updateTitle(to);

    expect(document.title).toBe(`Container · Virtual Registries · ${originalTitle}`);
  });

  it('handles empty matched array', () => {
    const to = {
      matched: [],
    };

    updateTitle(to);

    expect(document.title).toBe(originalTitle);
  });

  it('handles routes with empty meta.text', () => {
    const to = {
      matched: [{ meta: { text: '' } }, { meta: { text: 'Container' } }],
    };

    updateTitle(to);

    expect(document.title).toBe(`Container · ${originalTitle}`);
  });

  it('preserves order of matched routes in title', () => {
    const to = {
      matched: [
        { meta: { text: 'First' } },
        { meta: { text: 'Second' } },
        { meta: { text: 'Third' } },
      ],
    };

    updateTitle(to);

    expect(document.title).toBe(`Third · Second · First · ${originalTitle}`);
  });
});
