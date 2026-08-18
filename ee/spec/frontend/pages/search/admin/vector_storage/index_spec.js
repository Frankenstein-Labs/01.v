import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';

describe('ee/pages/search/admin/vector_storage/index', () => {
  const createFixture = (selectedAdapter = 'elasticsearch') => {
    setHTMLFixture(`
      <select class="js-adapter-select" data-testid="adapter-select">
        <option value="elasticsearch" ${selectedAdapter === 'elasticsearch' ? 'selected' : ''}>Elasticsearch</option>
        <option value="opensearch" ${selectedAdapter === 'opensearch' ? 'selected' : ''}>OpenSearch</option>
        <option value="postgresql" ${selectedAdapter === 'postgresql' ? 'selected' : ''}>PostgreSQL</option>
      </select>
      <div class="js-elasticsearch-section" data-testid="elasticsearch-section"></div>
      <div class="js-opensearch-section" data-testid="opensearch-section"></div>
      <div class="js-postgresql-section" data-testid="postgresql-section"></div>
    `);
  };

  const loadScript = async () => {
    await import('ee/pages/search/admin/vector_storage/index');
  };

  const findElasticsearchSection = () =>
    document.querySelector('[data-testid="elasticsearch-section"]');
  const findOpensearchSection = () => document.querySelector('[data-testid="opensearch-section"]');
  const findPostgresqlSection = () => document.querySelector('[data-testid="postgresql-section"]');

  const changeAdapter = (value) => {
    const select = document.querySelector('[data-testid="adapter-select"]');
    select.value = value;
    select.dispatchEvent(new Event('change'));
  };

  afterEach(() => {
    resetHTMLFixture();
    jest.resetModules();
  });

  describe('when the adapter select is absent', () => {
    it('does not throw', async () => {
      setHTMLFixture('<div></div>');

      await expect(loadScript()).resolves.not.toThrow();
    });
  });

  describe('initial state', () => {
    it('shows the elasticsearch section when elasticsearch is selected on load', async () => {
      createFixture('elasticsearch');
      await loadScript();

      expect(findElasticsearchSection()).not.toHaveClass('gl-hidden');
      expect(findOpensearchSection()).toHaveClass('gl-hidden');
      expect(findPostgresqlSection()).toHaveClass('gl-hidden');
    });

    it('shows the opensearch section when opensearch is selected on load', async () => {
      createFixture('opensearch');
      await loadScript();

      expect(findOpensearchSection()).not.toHaveClass('gl-hidden');
      expect(findElasticsearchSection()).toHaveClass('gl-hidden');
      expect(findPostgresqlSection()).toHaveClass('gl-hidden');
    });

    it('shows the postgresql section when postgresql is selected on load', async () => {
      createFixture('postgresql');
      await loadScript();

      expect(findPostgresqlSection()).not.toHaveClass('gl-hidden');
      expect(findElasticsearchSection()).toHaveClass('gl-hidden');
      expect(findOpensearchSection()).toHaveClass('gl-hidden');
    });
  });

  describe('when the adapter select changes', () => {
    it('shows the opensearch section and hides elasticsearch when switching to opensearch', async () => {
      createFixture('elasticsearch');
      await loadScript();

      changeAdapter('opensearch');

      expect(findOpensearchSection()).not.toHaveClass('gl-hidden');
      expect(findElasticsearchSection()).toHaveClass('gl-hidden');
      expect(findPostgresqlSection()).toHaveClass('gl-hidden');
    });

    it('shows the elasticsearch section and hides opensearch when switching to elasticsearch', async () => {
      createFixture('opensearch');
      await loadScript();

      changeAdapter('elasticsearch');

      expect(findElasticsearchSection()).not.toHaveClass('gl-hidden');
      expect(findOpensearchSection()).toHaveClass('gl-hidden');
      expect(findPostgresqlSection()).toHaveClass('gl-hidden');
    });

    it('shows the postgresql section and hides others when switching to postgresql', async () => {
      createFixture('elasticsearch');
      await loadScript();

      changeAdapter('postgresql');

      expect(findPostgresqlSection()).not.toHaveClass('gl-hidden');
      expect(findElasticsearchSection()).toHaveClass('gl-hidden');
      expect(findOpensearchSection()).toHaveClass('gl-hidden');
    });

    it('shows the elasticsearch section and hides postgresql when switching from postgresql', async () => {
      createFixture('postgresql');
      await loadScript();

      changeAdapter('elasticsearch');

      expect(findElasticsearchSection()).not.toHaveClass('gl-hidden');
      expect(findPostgresqlSection()).toHaveClass('gl-hidden');
      expect(findOpensearchSection()).toHaveClass('gl-hidden');
    });
  });
});
