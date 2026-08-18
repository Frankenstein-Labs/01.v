import { setActivePinia, createPinia } from 'pinia';
import { useChartExportStore } from 'ee/security_dashboard/stores/chart_export_store';

describe('Chart Export Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  describe('register', () => {
    it('registers a chart exporter function', () => {
      const store = useChartExportStore();
      const mockFn = jest.fn();

      store.register('test-chart', mockFn);

      expect(store.exporters['test-chart']).toBe(mockFn);
    });

    it('allows registering multiple exporters', () => {
      const store = useChartExportStore();
      const mockFn1 = jest.fn();
      const mockFn2 = jest.fn();

      store.register('chart-1', mockFn1);
      store.register('chart-2', mockFn2);

      expect(store.exporters['chart-1']).toBe(mockFn1);
      expect(store.exporters['chart-2']).toBe(mockFn2);
    });

    it('throws an error when exporter with the same id is already registered', () => {
      const store = useChartExportStore();
      const mockFn1 = jest.fn();
      const mockFn2 = jest.fn();

      store.register('test-chart', mockFn1);

      expect(() => store.register('test-chart', mockFn2)).toThrow(
        `Chart exporter with id "test-chart" is already registered.`,
      );
    });
  });

  describe('registerNested', () => {
    it('registers a function under a group and key', () => {
      const store = useChartExportStore();
      const mockFn = jest.fn();

      store.registerNested('my-group', 'key-a', mockFn);

      expect(store.nestedExporters['my-group']['key-a']).toBe(mockFn);
    });

    it('allows registering multiple keys under the same group', () => {
      const store = useChartExportStore();
      const mockFn1 = jest.fn();
      const mockFn2 = jest.fn();

      store.registerNested('my-group', 'key-a', mockFn1);
      store.registerNested('my-group', 'key-b', mockFn2);

      expect(store.nestedExporters['my-group']['key-a']).toBe(mockFn1);
      expect(store.nestedExporters['my-group']['key-b']).toBe(mockFn2);
    });

    it('throws when groupId is already registered as a flat exporter', () => {
      const store = useChartExportStore();

      store.register('my-group', jest.fn());

      expect(() => store.registerNested('my-group', 'key-a', jest.fn())).toThrow(
        `Chart exporter with id "my-group" is already registered as a flat exporter.`,
      );
    });

    it('throws when the same group and key are already registered', () => {
      const store = useChartExportStore();

      store.registerNested('my-group', 'key-a', jest.fn());

      expect(() => store.registerNested('my-group', 'key-a', jest.fn())).toThrow(
        `Nested chart exporter with group "my-group" and key "key-a" is already registered.`,
      );
    });
  });

  describe('unregisterNested', () => {
    it('removes a registered nested exporter', () => {
      const store = useChartExportStore();

      store.registerNested('my-group', 'key-a', jest.fn());
      expect(store.nestedExporters['my-group']).toHaveProperty('key-a');

      store.unregisterNested('my-group', 'key-a');
      expect(store.nestedExporters['my-group']).toBeUndefined();
    });

    it('removes the group when the last key is unregistered', () => {
      const store = useChartExportStore();

      store.registerNested('my-group', 'key-a', jest.fn());
      store.registerNested('my-group', 'key-b', jest.fn());

      store.unregisterNested('my-group', 'key-a');
      expect(store.nestedExporters['my-group']).toHaveProperty('key-b');

      store.unregisterNested('my-group', 'key-b');
      expect(store.nestedExporters['my-group']).toBeUndefined();
    });

    it('does not throw when unregistering a non-existent group or key', () => {
      const store = useChartExportStore();

      expect(() => store.unregisterNested('non-existent-group', 'key')).not.toThrow();
    });
  });

  describe('unregister', () => {
    it('removes a registered exporter', () => {
      const store = useChartExportStore();
      const mockFn = jest.fn();

      store.register('test-chart', mockFn);
      expect(store.exporters['test-chart']).toBeDefined();

      store.unregister('test-chart');
      expect(store.exporters['test-chart']).toBeUndefined();
    });

    it('does not throw when unregistering a non-existent exporter', () => {
      const store = useChartExportStore();

      expect(() => {
        store.unregister('non-existent');
      }).not.toThrow();
    });

    it('only removes the specified exporter', () => {
      const store = useChartExportStore();
      const mockFn1 = jest.fn();
      const mockFn2 = jest.fn();

      store.register('chart-1', mockFn1);
      store.register('chart-2', mockFn2);

      store.unregister('chart-1');

      expect(store.exporters['chart-1']).toBeUndefined();
      expect(store.exporters['chart-2']).toBe(mockFn2);
    });
  });

  describe('getAll', () => {
    it('returns an empty object when no exporters are registered', async () => {
      const store = useChartExportStore();

      const result = await store.getAll();

      expect(result).toEqual({});
    });

    it('calls all registered exporters and returns their results', async () => {
      const store = useChartExportStore();
      const mockFn1 = jest.fn().mockResolvedValue('svg-data-1');
      const mockFn2 = jest.fn().mockResolvedValue('svg-data-2');

      store.register('chart-1', mockFn1);
      store.register('chart-2', mockFn2);

      const result = await store.getAll();

      expect(mockFn1).toHaveBeenCalled();
      expect(mockFn2).toHaveBeenCalled();
      expect(result).toEqual({
        'chart-1': 'svg-data-1',
        'chart-2': 'svg-data-2',
      });
    });

    it('handles synchronous exporter functions', async () => {
      const store = useChartExportStore();
      const mockFn = jest.fn().mockReturnValue('svg-data');

      store.register('chart', mockFn);

      const result = await store.getAll();

      expect(result).toEqual({
        chart: 'svg-data',
      });
    });

    it('handles mixed synchronous and asynchronous exporters', async () => {
      const store = useChartExportStore();
      const syncFn = jest.fn().mockReturnValue('sync-data');
      const asyncFn = jest.fn().mockResolvedValue('async-data');

      store.register('sync-chart', syncFn);
      store.register('async-chart', asyncFn);

      const result = await store.getAll();

      expect(result).toEqual({
        'sync-chart': 'sync-data',
        'async-chart': 'async-data',
      });
    });

    it('resolves nested exporters into a nested object', async () => {
      const store = useChartExportStore();

      store.registerNested('my-group', 'key-a', jest.fn().mockResolvedValue('value-a'));
      store.registerNested('my-group', 'key-b', jest.fn().mockReturnValue('value-b'));

      const result = await store.getAll();

      expect(result).toEqual({
        'my-group': { 'key-a': 'value-a', 'key-b': 'value-b' },
      });
    });

    it('returns both flat and nested exporters together', async () => {
      const store = useChartExportStore();

      store.register('flat-chart', jest.fn().mockResolvedValue('svg'));
      store.registerNested('my-group', 'key-a', jest.fn().mockResolvedValue('value-a'));

      const result = await store.getAll();

      expect(result).toEqual({
        'flat-chart': 'svg',
        'my-group': { 'key-a': 'value-a' },
      });
    });

    it('rejects if any exporter throws an error', async () => {
      const store = useChartExportStore();
      const mockFn1 = jest.fn().mockResolvedValue('svg-data-1');
      const mockFn2 = jest.fn().mockRejectedValue(new Error('Export failed'));

      store.register('chart-1', mockFn1);
      store.register('chart-2', mockFn2);

      await expect(store.getAll()).rejects.toThrow('Export failed');
    });

    it('handles exporters that return undefined', async () => {
      const store = useChartExportStore();
      const mockFn1 = jest.fn().mockResolvedValue('svg-data');
      const mockFn2 = jest.fn().mockResolvedValue(undefined);

      store.register('chart-1', mockFn1);
      store.register('chart-2', mockFn2);

      const result = await store.getAll();

      expect(result).toEqual({
        'chart-1': 'svg-data',
        'chart-2': undefined,
      });
    });

    it('handles exporters that return null', async () => {
      const store = useChartExportStore();
      const mockFn1 = jest.fn().mockResolvedValue('svg-data');
      const mockFn2 = jest.fn().mockResolvedValue(null);

      store.register('chart-1', mockFn1);
      store.register('chart-2', mockFn2);

      const result = await store.getAll();

      expect(result).toEqual({
        'chart-1': 'svg-data',
        'chart-2': null,
      });
    });

    it('preserves the order of exporters in the result', async () => {
      const store = useChartExportStore();
      const mockFn1 = jest.fn().mockResolvedValue('data-1');
      const mockFn2 = jest.fn().mockResolvedValue('data-2');
      const mockFn3 = jest.fn().mockResolvedValue('data-3');

      store.register('chart-a', mockFn1);
      store.register('chart-b', mockFn2);
      store.register('chart-c', mockFn3);

      const result = await store.getAll();
      const keys = Object.keys(result);

      expect(keys).toContain('chart-a');
      expect(keys).toContain('chart-b');
      expect(keys).toContain('chart-c');
    });
  });

  describe('store isolation', () => {
    it('creates separate store instances for different pinia instances', () => {
      const store1 = useChartExportStore();
      const mockFn1 = jest.fn();
      store1.register('chart', mockFn1);

      setActivePinia(createPinia());
      const store2 = useChartExportStore();

      expect(store2.exporters.chart).toBeUndefined();
    });
  });
});
