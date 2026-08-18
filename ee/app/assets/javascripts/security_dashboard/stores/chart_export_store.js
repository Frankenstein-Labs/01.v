import { defineStore } from 'pinia';
import { reactive } from 'vue';

export const useChartExportStore = defineStore('chartExport', () => {
  const exporters = reactive({});
  const nestedExporters = reactive({});

  const register = (id, fn) => {
    if (typeof exporters[id] !== 'undefined') {
      throw new Error(`Chart exporter with id "${id}" is already registered.`);
    }

    exporters[id] = fn;
  };

  const unregister = (id) => {
    delete exporters[id];
  };

  const registerNested = (groupId, key, fn) => {
    if (typeof exporters[groupId] !== 'undefined') {
      throw new Error(
        `Chart exporter with id "${groupId}" is already registered as a flat exporter.`,
      );
    }

    if (nestedExporters[groupId]?.[key] !== undefined) {
      throw new Error(
        `Nested chart exporter with group "${groupId}" and key "${key}" is already registered.`,
      );
    }

    if (!nestedExporters[groupId]) {
      nestedExporters[groupId] = {};
    }
    nestedExporters[groupId][key] = fn;
  };

  const unregisterNested = (groupId, key) => {
    if (nestedExporters[groupId]) {
      delete nestedExporters[groupId][key];
      if (Object.keys(nestedExporters[groupId]).length === 0) {
        delete nestedExporters[groupId];
      }
    }
  };

  const resolveExporterEntries = async (exporterMap) =>
    Promise.all(Object.entries(exporterMap).map(async ([key, fn]) => [key, await fn()]));

  const getAll = async () => {
    const flatEntries = await resolveExporterEntries(exporters);

    const nestedEntries = await Promise.all(
      Object.entries(nestedExporters).map(async ([groupId, groupExporters]) => {
        const resolvedGroupExporters = await resolveExporterEntries(groupExporters);
        return [groupId, Object.fromEntries(resolvedGroupExporters)];
      }),
    );

    return Object.fromEntries([...flatEntries, ...nestedEntries]);
  };

  return {
    exporters,
    nestedExporters,
    register,
    unregister,
    registerNested,
    unregisterNested,
    getAll,
  };
});
