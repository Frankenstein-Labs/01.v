import { GlAlert, GlCollapsibleListbox, GlKeysetPagination, GlTable } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { DEFAULT_PER_PAGE } from '~/api';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ServicesSelector from 'ee/cd/components/services_selector.vue';
import cdApplicationServiceVersionsQuery from 'ee/cd/graphql/cd_application_service_versions.query.graphql';
import {
  cdApplicationId,
  mockServices,
  serviceWithoutVersions,
  serviceWithEmptySource,
  serviceWithVersions,
  serviceWithMultipleSources,
  cdApplicationServicesResponse,
} from '../mock_data';

Vue.use(VueApollo);

describe('ServicesSelector', () => {
  let wrapper;

  const firstPageVariables = {
    first: DEFAULT_PER_PAGE,
    after: null,
    last: null,
    before: null,
  };

  const defaultHandler = jest.fn().mockResolvedValue(cdApplicationServicesResponse());

  const findTable = () => wrapper.findComponent(GlTable);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findVersionListboxes = () => wrapper.findAllComponents(GlCollapsibleListbox);
  const findRows = () => wrapper.findAll('tbody tr');
  const findServiceNames = () => wrapper.findAllByTestId('service-name');
  const findSourceRefs = () => wrapper.findAllByTestId('source-ref');
  const findChangedLabels = () => wrapper.findAllByTestId('version-changed');
  const lastEmitted = (event) => wrapper.emitted(event).at(-1)[0];

  const createComponent = ({ handler = defaultHandler } = {}) => {
    wrapper = mountExtended(ServicesSelector, {
      apolloProvider: createMockApollo([[cdApplicationServiceVersionsQuery, handler]]),
      propsData: { applicationId: cdApplicationId },
    });
  };

  it('requests the first page of services for the given application id', async () => {
    createComponent();
    await waitForPromises();

    expect(defaultHandler).toHaveBeenCalledWith({
      applicationId: cdApplicationId,
      ...firstPageVariables,
    });
  });

  describe('while loading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('sets the table to busy', () => {
      expect(findTable().attributes('aria-busy')).toBe('true');
    });
  });

  describe('when the query errors', () => {
    beforeEach(async () => {
      createComponent({ handler: jest.fn().mockRejectedValue(new Error('Network error')) });
      await waitForPromises();
    });

    it('renders an error alert with a message', () => {
      expect(findAlert().text()).toBe('Failed to load services. Refresh the page to try again.');
    });
  });

  describe('with single-source services', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders a row per source', () => {
      expect(findTable().props('items')).toHaveLength(mockServices.length);
      expect(findVersionListboxes()).toHaveLength(mockServices.length);
    });

    it('renders the service names', () => {
      expect(wrapper.text()).toContain('payment-api');
      expect(wrapper.text()).toContain('fraud-detector');
    });

    it('renders the artifact source ref for each source', () => {
      expect(wrapper.text()).toContain('registry.example.com/payment-api');
      expect(wrapper.text()).toContain('registry.example.com/fraud-detector');
    });

    it('labels each version selector by its service and source for screen readers', () => {
      expect(findServiceNames().at(0).attributes('id')).toBe('cd-service-1');
      expect(findSourceRefs().at(0).attributes('id')).toBe('cd-source-1');
      expect(findVersionListboxes().at(0).props('toggleAriaLabelledBy')).toBe(
        'cd-service-1 cd-source-1',
      );
    });

    it('lists the versions newest-first', () => {
      expect(findVersionListboxes().at(0).props('items')).toEqual([
        { value: 'gid://gitlab/Cd::Version/2', text: 'v2.0.0' },
        { value: 'gid://gitlab/Cd::Version/1', text: 'v1.0.0' },
      ]);
    });

    it('preselects the version from the most recent release', () => {
      expect(findVersionListboxes().at(0).props('selected')).toBe('gid://gitlab/Cd::Version/1');
      expect(findVersionListboxes().at(0).props('toggleText')).toBe('v1.0.0');
    });

    it('emits the preselected versions', () => {
      expect(lastEmitted('change')).toEqual([
        {
          serviceId: 'gid://gitlab/Cd::Service/1',
          sourceId: 'gid://gitlab/Cd::ArtifactSource/1',
          versionId: 'gid://gitlab/Cd::Version/1',
        },
        {
          serviceId: 'gid://gitlab/Cd::Service/2',
          sourceId: 'gid://gitlab/Cd::ArtifactSource/2',
          versionId: 'gid://gitlab/Cd::Version/3',
        },
      ]);
    });

    describe('when a different version is selected', () => {
      beforeEach(async () => {
        findVersionListboxes().at(0).vm.$emit('select', 'gid://gitlab/Cd::Version/2');
        await nextTick();
      });

      it('emits the chosen version', () => {
        expect(lastEmitted('change')).toEqual([
          {
            serviceId: 'gid://gitlab/Cd::Service/1',
            sourceId: 'gid://gitlab/Cd::ArtifactSource/1',
            versionId: 'gid://gitlab/Cd::Version/2',
          },
          {
            serviceId: 'gid://gitlab/Cd::Service/2',
            sourceId: 'gid://gitlab/Cd::ArtifactSource/2',
            versionId: 'gid://gitlab/Cd::Version/3',
          },
        ]);
      });
    });
  });

  describe('when the most recent release has no matching version', () => {
    beforeEach(async () => {
      createComponent({
        handler: jest.fn().mockResolvedValue(
          cdApplicationServicesResponse(mockServices, {
            presetVersionIds: ['gid://gitlab/Cd::Version/999'],
          }),
        ),
      });
      await waitForPromises();
    });

    it('preselects nothing', () => {
      expect(findVersionListboxes().at(0).props('selected')).toBe(null);
      expect(findVersionListboxes().at(0).props('toggleText')).toBe('Select version');
    });

    it('emits an empty selection', () => {
      expect(lastEmitted('change')).toEqual([]);
    });
  });

  describe('change tracking', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('shows no changed rows while nothing is changed', () => {
      expect(findChangedLabels()).toHaveLength(0);
    });

    it('does not emit a changed count while nothing is changed', () => {
      expect(wrapper.emitted('changed-count')).toBeUndefined();
    });

    describe('after changing a version', () => {
      beforeEach(async () => {
        findVersionListboxes().at(0).vm.$emit('select', 'gid://gitlab/Cd::Version/2');
        await nextTick();
      });

      it('shows the Changed label on the changed row only', () => {
        expect(findChangedLabels()).toHaveLength(1);
        expect(findChangedLabels().at(0).text()).toBe('Changed');
      });

      it('emits the number of changed sources', () => {
        expect(lastEmitted('changed-count')).toBe(1);
      });

      describe('when reverted to the preselected version', () => {
        beforeEach(async () => {
          findVersionListboxes().at(0).vm.$emit('select', 'gid://gitlab/Cd::Version/1');
          await nextTick();
        });

        it('hides the Changed label again', () => {
          expect(findChangedLabels()).toHaveLength(0);
        });

        it('emits a changed count of zero', () => {
          expect(lastEmitted('changed-count')).toBe(0);
        });
      });
    });
  });

  describe('a service with multiple sources', () => {
    beforeEach(async () => {
      createComponent({
        handler: jest.fn().mockResolvedValue(
          cdApplicationServicesResponse([serviceWithMultipleSources], {
            presetVersionIds: ['gid://gitlab/Cd::Version/21', 'gid://gitlab/Cd::Version/22'],
          }),
        ),
      });
      await waitForPromises();
    });

    it('renders a service header row plus a row per source', () => {
      expect(findRows()).toHaveLength(3);
      expect(findServiceNames()).toHaveLength(1);
      expect(findServiceNames().at(0).text()).toBe('checkout');
    });

    it('renders the header row without a version picker', () => {
      expect(findRows().at(0).findComponent(GlCollapsibleListbox).exists()).toBe(false);
    });

    it('renders each source ref with its own version selector', () => {
      expect(findSourceRefs()).toHaveLength(2);
      expect(findVersionListboxes()).toHaveLength(2);
      expect(wrapper.text()).toContain('registry.example.com/checkout-amd64');
      expect(wrapper.text()).toContain('registry.example.com/checkout-arm64');
    });

    it('preselects the latest release version of each source independently', () => {
      expect(lastEmitted('change')).toEqual([
        {
          serviceId: 'gid://gitlab/Cd::Service/7',
          sourceId: 'gid://gitlab/Cd::ArtifactSource/71',
          versionId: 'gid://gitlab/Cd::Version/21',
        },
        {
          serviceId: 'gid://gitlab/Cd::Service/7',
          sourceId: 'gid://gitlab/Cd::ArtifactSource/72',
          versionId: 'gid://gitlab/Cd::Version/22',
        },
      ]);
    });

    describe('when a version is selected', () => {
      beforeEach(async () => {
        findVersionListboxes().at(0).vm.$emit('select', 'gid://gitlab/Cd::Version/20');
        await nextTick();
      });

      it('updates only the changed source', () => {
        expect(lastEmitted('change')).toEqual([
          {
            serviceId: 'gid://gitlab/Cd::Service/7',
            sourceId: 'gid://gitlab/Cd::ArtifactSource/71',
            versionId: 'gid://gitlab/Cd::Version/20',
          },
          {
            serviceId: 'gid://gitlab/Cd::Service/7',
            sourceId: 'gid://gitlab/Cd::ArtifactSource/72',
            versionId: 'gid://gitlab/Cd::Version/22',
          },
        ]);
      });
    });

    describe('when the release matches only some of the sources', () => {
      beforeEach(async () => {
        createComponent({
          handler: jest.fn().mockResolvedValue(
            cdApplicationServicesResponse([serviceWithMultipleSources], {
              presetVersionIds: ['gid://gitlab/Cd::Version/21'],
            }),
          ),
        });
        await waitForPromises();
      });

      it('preselects the matched source and leaves the rest unselected', () => {
        expect(lastEmitted('change')).toEqual([
          {
            serviceId: 'gid://gitlab/Cd::Service/7',
            sourceId: 'gid://gitlab/Cd::ArtifactSource/71',
            versionId: 'gid://gitlab/Cd::Version/21',
          },
        ]);
        expect(findVersionListboxes().at(1).props('toggleText')).toBe('Select version');
      });
    });
  });

  describe('a service without versions', () => {
    beforeEach(async () => {
      createComponent({
        handler: jest
          .fn()
          .mockResolvedValue(cdApplicationServicesResponse([serviceWithoutVersions])),
      });
      await waitForPromises();
    });

    it('renders a row with no version selector', () => {
      expect(findRows()).toHaveLength(1);
      expect(findVersionListboxes()).toHaveLength(0);
    });

    it('excludes it from the emitted selection', () => {
      expect(lastEmitted('change')).toEqual([]);
    });
  });

  describe('a source without versions', () => {
    beforeEach(async () => {
      createComponent({
        handler: jest
          .fn()
          .mockResolvedValue(cdApplicationServicesResponse([serviceWithEmptySource])),
      });
      await waitForPromises();
    });

    it('shows a "Select version" placeholder in the version selector', () => {
      expect(findVersionListboxes()).toHaveLength(1);
      expect(findVersionListboxes().at(0).props('toggleText')).toBe('Select version');
    });

    it('excludes it from the emitted selection', () => {
      expect(lastEmitted('change')).toEqual([]);
    });
  });

  describe('pagination', () => {
    const pageInfo = {
      hasNextPage: true,
      hasPreviousPage: true,
      startCursor: 'START',
      endCursor: 'END',
    };

    describe('when there are no more pages', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('does not render the pager', () => {
        expect(findPagination().exists()).toBe(false);
      });
    });

    describe('when there are more pages', () => {
      let handler;

      beforeEach(async () => {
        handler = jest
          .fn()
          .mockResolvedValue(cdApplicationServicesResponse(mockServices, { pageInfo }));
        createComponent({ handler });
        await waitForPromises();
      });

      it('renders the pager', () => {
        expect(findPagination().exists()).toBe(true);
      });

      it('requests the next page using the end cursor', async () => {
        findPagination().vm.$emit('next', 'END');
        await waitForPromises();

        expect(handler).toHaveBeenLastCalledWith({
          applicationId: cdApplicationId,
          first: DEFAULT_PER_PAGE,
          after: 'END',
          last: null,
          before: null,
        });
      });

      it('requests the previous page using the start cursor', async () => {
        findPagination().vm.$emit('prev', 'START');
        await waitForPromises();

        expect(handler).toHaveBeenLastCalledWith({
          applicationId: cdApplicationId,
          first: null,
          after: null,
          last: DEFAULT_PER_PAGE,
          before: 'START',
        });
      });

      describe('across pages', () => {
        const presetVersionIds = [
          'gid://gitlab/Cd::Version/2',
          'gid://gitlab/Cd::Version/3',
          'gid://gitlab/Cd::Version/11',
        ];

        beforeEach(async () => {
          const pagedHandler = jest
            .fn()
            .mockResolvedValueOnce(
              cdApplicationServicesResponse(mockServices, {
                pageInfo: { hasNextPage: true, endCursor: 'END' },
                presetVersionIds,
              }),
            )
            .mockResolvedValueOnce(
              cdApplicationServicesResponse([serviceWithVersions], { presetVersionIds }),
            );
          createComponent({ handler: pagedHandler });
          await waitForPromises();
        });

        it('keeps selections from earlier pages in the emitted selection', async () => {
          findPagination().vm.$emit('next', 'END');
          await waitForPromises();

          expect(lastEmitted('change')).toEqual([
            {
              serviceId: 'gid://gitlab/Cd::Service/1',
              sourceId: 'gid://gitlab/Cd::ArtifactSource/1',
              versionId: 'gid://gitlab/Cd::Version/2',
            },
            {
              serviceId: 'gid://gitlab/Cd::Service/2',
              sourceId: 'gid://gitlab/Cd::ArtifactSource/2',
              versionId: 'gid://gitlab/Cd::Version/3',
            },
            {
              serviceId: 'gid://gitlab/Cd::Service/5',
              sourceId: 'gid://gitlab/Cd::ArtifactSource/5',
              versionId: 'gid://gitlab/Cd::Version/11',
            },
          ]);
        });

        it('keeps the changed count from earlier pages', async () => {
          findVersionListboxes().at(0).vm.$emit('select', 'gid://gitlab/Cd::Version/1');
          await nextTick();
          expect(lastEmitted('changed-count')).toBe(1);

          findPagination().vm.$emit('next', 'END');
          await waitForPromises();

          expect(lastEmitted('changed-count')).toBe(1);
        });
      });
    });
  });

  describe('with no services', () => {
    beforeEach(async () => {
      createComponent({ handler: jest.fn().mockResolvedValue(cdApplicationServicesResponse([])) });
      await waitForPromises();
    });

    it('shows the empty state', () => {
      expect(wrapper.text()).toContain('No services to display.');
    });
  });
});
