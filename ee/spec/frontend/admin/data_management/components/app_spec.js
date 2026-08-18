import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueRouter from 'vue-router';
import { GlKeysetPagination } from '@gitlab/ui';
import models from 'test_fixtures/api/admin/data_management/snippet_repositories.json';
import AdminDataManagementApp from 'ee/admin/data_management/components/app.vue';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import { MOCK_MODEL_TYPES } from 'ee_jest/admin/data_management/mock_data';
import showToast from '~/vue_shared/plugins/global_toast';
import { BULK_ACTIONS } from 'ee/admin/data_management/constants';
import { getModels, putBulkModelAction } from 'ee/api/data_management_api';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import DataManagementItem from 'ee/admin/data_management/components/data_management_item.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { createRouter } from 'ee/admin/data_management/router';

Vue.use(VueRouter);

jest.mock('~/alert');
jest.mock('ee/api/data_management_api');
jest.mock('~/vue_shared/plugins/global_toast');

describe('AdminDataManagementApp', () => {
  let wrapper;
  let router;

  const [defaultModelType, otherModelType] = MOCK_MODEL_TYPES;
  const defaultModelTitle = defaultModelType.titlePlural.toLowerCase();
  const defaultBasePath = 'admin/data_management';

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMount(AdminDataManagementApp, {
      router,
      propsData: {
        modelTypes: MOCK_MODEL_TYPES,
        initialModelTypeName: defaultModelType.namePlural,
        ...props,
      },
    });
  };

  const findGeoListTopBar = () => wrapper.findComponent(GeoListTopBar);
  const findGeoList = () => wrapper.findComponent(GeoList);
  const findGlKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findDataManagementItem = () => wrapper.findComponent(DataManagementItem);

  const fireBulkAction = (action) => findGeoListTopBar().vm.$emit('bulk-action', action);

  beforeEach(() => {
    router = createRouter(defaultBasePath);
  });

  describe('when checksumEnabled is true', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GeoListTopBar with bulk actions', () => {
      expect(findGeoListTopBar().props()).toMatchObject({
        pageHeadingTitle: 'Data management',
        pageHeadingDescription: 'Review stored data and data health within your instance.',
        filteredSearchOptionLabel: 'Search by ID',
        activeListboxItem: defaultModelType.namePlural,
        activeSort: { value: 'id', direction: 'asc' },
        bulkActions: BULK_ACTIONS,
        showActions: false,
      });
    });
  });

  describe('when checksumEnabled is false', () => {
    beforeEach(() => {
      createComponent({ props: { modelTypes: [{ ...defaultModelType, checksumEnabled: false }] } });
    });

    it('renders GeoListTopBar without bulk actions', () => {
      expect(findGeoListTopBar().props()).toMatchObject({
        pageHeadingTitle: 'Data management',
        pageHeadingDescription: 'Review stored data and data health within your instance.',
        filteredSearchOptionLabel: 'Search by ID',
        activeListboxItem: defaultModelType.namePlural,
        activeSort: { value: 'id', direction: 'asc' },
        bulkActions: [],
        showActions: false,
      });
    });
  });

  it('renders GeoList', () => {
    createComponent();

    expect(findGeoList().props()).toMatchObject({
      isLoading: true,
      hasItems: false,
      emptyState: {
        title: `No ${defaultModelTitle} exist`,
        description:
          'If you believe this is an error, see the %{linkStart}Geo troubleshooting%{linkEnd} documentation.',
        helpLink: '/help/administration/geo/replication/troubleshooting/_index.md',
        hasFilters: false,
      },
    });
  });

  describe('API calls', () => {
    it('calls getModels with correct parameters', () => {
      createComponent();

      expect(getModels).toHaveBeenCalledWith(defaultModelType.namePlural, {
        order_by: 'id',
        sort: 'asc',
        pagination: 'keyset',
      });
    });

    describe('while loading model is querying', () => {
      it('shows loading state', () => {
        createComponent();

        expect(findGeoList().props('isLoading')).toBe(true);
        expect(findGlKeysetPagination().props('disabled')).toBe(true);
      });
    });

    describe('when loading models succeeds', () => {
      beforeEach(async () => {
        getModels.mockResolvedValue({
          data: models,
          headers: { 'x-next-cursor': 'next', 'x-prev-cursor': 'prev' },
        });
        createComponent();
        await waitForPromises();
      });

      it('renders items on GeoList', () => {
        const [item] = convertObjectPropsToCamelCase(models, { deep: true });

        expect(findGeoList().props('hasItems')).toBe(true);
        expect(findDataManagementItem().props()).toMatchObject({
          initialItem: item,
          activeModelType: defaultModelType,
        });
      });

      it('stops loading state', () => {
        expect(findGeoList().props('isLoading')).toBe(false);
        expect(findGlKeysetPagination().props('disabled')).toBe(false);
      });

      it('does not create alert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });

      it('shows bulk actions', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(true);
      });
    });

    describe('when loading models returns empty array', () => {
      beforeEach(async () => {
        getModels.mockResolvedValue({
          data: [],
          headers: { 'x-next-cursor': 'next', 'x-prev-cursor': 'prev' },
        });
        createComponent();
        await waitForPromises();
      });

      it('shows empty state', () => {
        expect(findGeoList().props('hasItems')).toBe(false);
        expect(findGeoList().findAll('li')).toHaveLength(0);
      });

      it('stops loading state', () => {
        expect(findGeoList().props('isLoading')).toBe(false);
        expect(findGlKeysetPagination().props('disabled')).toBe(false);
      });

      it('does not create alert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });

      it('does not show bulk actions', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(false);
      });
    });

    describe('when loading models fails', () => {
      const error = new Error('Failed to load models');

      beforeEach(async () => {
        getModels.mockRejectedValue(error);
        createComponent();
        await waitForPromises();
      });

      it('creates alert', () => {
        const message = `There was an error fetching ${defaultModelTitle}. Please refresh the page and try again.`;
        expect(createAlert).toHaveBeenCalledWith({ message, captureError: true, error });
      });

      it('stops loading state', () => {
        expect(findGeoList().props('isLoading')).toBe(false);
        expect(findGlKeysetPagination().props('disabled')).toBe(false);
      });

      it('does not show bulk actions', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(false);
      });
    });
  });

  describe('when URL has params', () => {
    beforeEach(async () => {
      await router.push({
        name: 'root',
        params: { modelName: otherModelType.namePlural },
        query: {
          identifiers: ['123', '456'],
          checksum_state: 'failed',
          order_by: 'name',
          sort: 'desc',
          cursor: 'cursor',
        },
      });

      createComponent();
    });

    it('updates route modelName', () => {
      expect(router.currentRoute.params.modelName).toBe(otherModelType.namePlural);
    });

    it('updates route query', () => {
      expect(router.currentRoute.query).toStrictEqual({
        checksum_state: 'failed',
        identifiers: ['123', '456'],
        order_by: 'name',
        sort: 'desc',
        cursor: 'cursor',
      });
    });

    it('calls getModels with correct parameters', () => {
      expect(getModels).toHaveBeenCalledWith(otherModelType.namePlural, {
        identifiers: ['123', '456'],
        checksum_state: 'failed',
        order_by: 'name',
        sort: 'desc',
        pagination: 'keyset',
        cursor: 'cursor',
      });
    });

    it('passes initial filter to GeoListTopBar', () => {
      expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toMatchObject([
        '123 456',
        { type: 'checksum_state', value: { data: 'failed' } },
      ]);
    });

    it('sets emptyState hasFilter field to true', () => {
      expect(findGeoList().props()).toMatchObject({
        emptyState: { hasFilters: true },
      });
    });
  });

  describe('when GeoListTopBar emits `listbox-change` event', () => {
    beforeEach(async () => {
      await router.push({
        name: 'root',
        query: { identifiers: [1], order_by: 'name', sort: 'asc', cursor: 'cursor' },
      });

      createComponent();

      findGeoListTopBar().vm.$emit('listbox-change', otherModelType.namePlural);
      await waitForPromises();
    });

    it('updates route modelName', () => {
      expect(router.currentRoute.params.modelName).toBe(otherModelType.namePlural);
    });

    it('retains route query except cursor', () => {
      expect(router.currentRoute.query).toStrictEqual({
        identifiers: ['1'],
        order_by: 'name',
        sort: 'asc',
      });
    });

    it('calls getModels with correct params', () => {
      expect(getModels).toHaveBeenCalledWith(otherModelType.namePlural, {
        identifiers: ['1'],
        order_by: 'name',
        sort: 'asc',
        pagination: 'keyset',
      });
    });
  });

  describe('when GeoListTopBar emits `search` event', () => {
    beforeEach(async () => {
      await router.push({
        name: 'root',
        params: { modelName: otherModelType.namePlural },
        query: { order_by: 'name', sort: 'asc', cursor: 'cursor' },
      });

      createComponent();

      findGeoListTopBar().vm.$emit('search', [
        '123 456',
        { type: 'checksum_state', value: { data: 'failed' } },
      ]);
      await waitForPromises();
    });

    it('does not change route params', () => {
      expect(router.currentRoute.params).toStrictEqual({ modelName: otherModelType.namePlural });
    });

    it('updates route filter query and drops cursor', () => {
      expect(router.currentRoute.query).toStrictEqual({
        identifiers: ['123', '456'],
        checksum_state: 'failed',
        order_by: 'name',
        sort: 'asc',
      });
    });

    it('calls getModels with updated filter params', () => {
      expect(getModels).toHaveBeenCalledWith(otherModelType.namePlural, {
        identifiers: ['123', '456'],
        checksum_state: 'failed',
        order_by: 'name',
        sort: 'asc',
        pagination: 'keyset',
      });
    });
  });

  describe('when GeoListTopBar emits `sort` event', () => {
    beforeEach(async () => {
      await router.push({
        name: 'root',
        params: { modelName: otherModelType.namePlural },
        query: { identifiers: ['123', '456'], order_by: 'updated-at', sort: 'asc' },
        cursor: 'cursor',
      });

      createComponent();

      findGeoListTopBar().vm.$emit('sort', { value: 'name', direction: 'desc' });
      await waitForPromises();
    });

    it('does not change route params', () => {
      expect(router.currentRoute.params).toStrictEqual({ modelName: otherModelType.namePlural });
    });

    it('updates route sort query and drops cursor', () => {
      expect(router.currentRoute.query).toStrictEqual({
        identifiers: ['123', '456'],
        order_by: 'name',
        sort: 'desc',
      });
    });

    it('calls getModels with new sort params', () => {
      expect(getModels).toHaveBeenCalledWith(otherModelType.namePlural, {
        identifiers: ['123', '456'],
        order_by: 'name',
        sort: 'desc',
        pagination: 'keyset',
      });
    });
  });

  describe('when GeoListTopBar emits `buildAction` event', () => {
    const [action] = BULK_ACTIONS;

    beforeEach(async () => {
      getModels.mockResolvedValue({ data: [], headers: {} });
      createComponent();

      await waitForPromises();
      getModels.mockClear();
    });

    it('calls putBulkModelAction', () => {
      fireBulkAction(action);

      expect(putBulkModelAction).toHaveBeenCalledWith(defaultModelType.namePlural, action.action);
    });

    describe('when action succeeds', () => {
      beforeEach(async () => {
        putBulkModelAction.mockResolvedValue({ data: defaultModelType });
        fireBulkAction(action);
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(showToast).toHaveBeenCalledWith(
          `Scheduled all ${defaultModelTitle} for checksum recalculation.`,
        );
      });

      it('does not create alert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });

      it('reloads models', () => {
        expect(getModels).toHaveBeenCalled();
      });
    });

    describe('when action fails', () => {
      const error = new Error('failed to run bulk action');

      beforeEach(async () => {
        putBulkModelAction.mockRejectedValue(error);
        fireBulkAction(action);
        await waitForPromises();
      });

      it('does not show toast', () => {
        expect(showToast).not.toHaveBeenCalled();
      });

      it('creates alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: `There was an error scheduling all ${defaultModelTitle} for checksum recalculation.`,
          captureError: true,
          error,
        });
      });

      it('does not reload models', () => {
        expect(getModels).not.toHaveBeenCalled();
      });
    });
  });

  describe('when has x-next-cursor', () => {
    beforeEach(async () => {
      getModels.mockResolvedValue({ data: models, headers: { 'x-next-cursor': 'next' } });
      createComponent();
      await waitForPromises();
    });

    it('enables next button on pagination', () => {
      expect(findGlKeysetPagination().props('hasNextPage')).toBe(true);
      expect(findGlKeysetPagination().props('hasPreviousPage')).toBe(false);
    });
  });

  describe('when has x-prev-cursor', () => {
    beforeEach(async () => {
      getModels.mockResolvedValue({ data: models, headers: { 'x-prev-cursor': 'prev' } });
      createComponent();
      await waitForPromises();
    });

    it('enables previous button on pagination', () => {
      expect(findGlKeysetPagination().props('hasPreviousPage')).toBe(true);
      expect(findGlKeysetPagination().props('hasNextPage')).toBe(false);
    });
  });

  describe('when GlKeysetPagination emits `next` event', () => {
    beforeEach(async () => {
      getModels.mockResolvedValue({
        data: models,
        headers: { 'x-next-cursor': 'next' },
      });

      await router.push({
        name: 'root',
        params: { modelName: defaultModelType.namePlural },
        query: { identifiers: ['123'], order_by: 'name', sort: 'asc' },
      });

      createComponent();
      await waitForPromises();

      findGlKeysetPagination().vm.$emit('next');
      await waitForPromises();
    });

    it('updates route with next cursor', () => {
      expect(router.currentRoute.query).toMatchObject({
        identifiers: ['123'],
        order_by: 'name',
        sort: 'asc',
        cursor: 'next',
      });
    });

    it('calls getModels with cursor param', () => {
      expect(getModels).toHaveBeenCalledWith(defaultModelType.namePlural, {
        identifiers: ['123'],
        order_by: 'name',
        sort: 'asc',
        pagination: 'keyset',
        cursor: 'next',
      });
    });
  });

  describe('when GlKeysetPagination emits `prev` event', () => {
    beforeEach(async () => {
      getModels.mockResolvedValue({
        data: models,
        headers: { 'x-prev-cursor': 'prev' },
      });

      await router.push({
        name: 'root',
        params: { modelName: defaultModelType.namePlural },
        query: { identifiers: ['456'], order_by: 'id', sort: 'desc' },
      });

      createComponent();
      await waitForPromises();

      findGlKeysetPagination().vm.$emit('prev');
      await waitForPromises();
    });

    it('updates route with previous cursor', () => {
      expect(router.currentRoute.query).toMatchObject({
        identifiers: ['456'],
        order_by: 'id',
        sort: 'desc',
        cursor: 'prev',
      });
    });

    it('calls getModels with cursor param', () => {
      expect(getModels).toHaveBeenCalledWith(defaultModelType.namePlural, {
        identifiers: ['456'],
        order_by: 'id',
        sort: 'desc',
        pagination: 'keyset',
        cursor: 'prev',
      });
    });
  });
});
