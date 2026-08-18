import mavenRegistryUpstreamsFixture from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registry_upstreams.query.graphql.json';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RegistryUpstreamItem from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/registry_upstream_item.vue';
import ContainerRoutes from 'ee/packages_and_registries/virtual_registries/pages/container/routes';

const { registryUpstreams } = mavenRegistryUpstreamsFixture.data.registry;

const [registryUpstream] = registryUpstreams;
const { upstream } = registryUpstream;

const defaultProps = {
  index: 1,
  upstreamsCount: 3,
  registryUpstream,
};

const defaultProvide = {
  glAbilities: {
    updateVirtualRegistry: true,
    destroyVirtualRegistry: true,
  },
  editUpstreamPathTemplate: 'path/:id/edit',
  showUpstreamPathTemplate: 'path/:id',
  routes: ContainerRoutes,
};

describe('RegistryUpstreamItem', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(RegistryUpstreamItem, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        GlTruncate: {
          template: '<div>{{ text }}</div>',
          props: ['text'],
        },
      },
    });
  };

  const findUpstreamName = () => wrapper.findComponentByTestId('upstream-name');
  const findUpstreamUrl = () => wrapper.findByTestId('upstream-url');
  const findCacheValidityHours = () => wrapper.findByTestId('cache-validity-hours');
  const findMetadataCacheValidityHours = () =>
    wrapper.findByTestId('metadata-cache-validity-hours');
  const findClearCacheButton = () => wrapper.findComponentByTestId('clear-cache-button');
  const findEditButton = () => wrapper.findComponentByTestId('edit-button');
  const findRemoveButton = () => wrapper.findComponentByTestId('remove-button');

  const findReorderUpButton = () => wrapper.findComponentByTestId('reorder-up-button');
  const findReorderDownButton = () => wrapper.findComponentByTestId('reorder-down-button');

  describe('renders', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the reorder up button', () => {
      expect(findReorderUpButton().props('disabled')).toBe(false);
    });

    it('reorder up button is disabled if upstream is the first upstream', () => {
      createComponent({ props: { index: 0 } });
      expect(findReorderUpButton().props('disabled')).toBe(true);
    });

    it('renders the reorder down button', () => {
      expect(findReorderDownButton().props('disabled')).toBe(false);
    });

    it('reorder down button is disabled if upstream is the last upstream', () => {
      createComponent({ props: { index: 2 } });
      expect(findReorderDownButton().props('disabled')).toBe(true);
    });

    it('does not render reorder buttons if `glAbilities.updateVirtualRegistry` is false', () => {
      createComponent({ provide: { glAbilities: { updateVirtualRegistry: false } } });

      expect(findReorderUpButton().exists()).toBe(false);
      expect(findReorderDownButton().exists()).toBe(false);
    });

    it('renders the upstream name', () => {
      expect(findUpstreamName().text()).toBe(upstream.name);
      expect(findUpstreamName().attributes('href')).toBe(`path/${getIdFromGraphQLId(upstream.id)}`);
      expect(findUpstreamName().props('to')).toEqual({
        name: ContainerRoutes.showUpstreamRouteName,
        params: { id: getIdFromGraphQLId(upstream.id) },
      });
    });

    it('renders the upstream url', () => {
      expect(findUpstreamUrl().text()).toBe(upstream.url);
    });

    it('renders artifact cache validity hours', () => {
      expect(findCacheValidityHours().text()).toBe('Artifact cache: 24 hours');
    });

    it('renders metadata cache validity hours', () => {
      expect(findMetadataCacheValidityHours().text()).toBe('Metadata cache: 48 hours');
    });

    it('renders the clear cache button if `glAbilities.updateVirtualRegistry` is true', () => {
      expect(findClearCacheButton().exists()).toBe(true);
    });

    it('does not render the clear cache button if `glAbilities.updateVirtualRegistry` is false', () => {
      createComponent({ provide: { glAbilities: { updateVirtualRegistry: false } } });
      expect(findClearCacheButton().exists()).toBe(false);
    });

    it('renders the edit button if `glAbilities.updateVirtualRegistry` is true', () => {
      expect(findEditButton().attributes('href')).toBe(
        `path/${getIdFromGraphQLId(upstream.id)}/edit`,
      );
      expect(findEditButton().props('to')).toEqual({
        name: ContainerRoutes.editUpstreamRouteName,
        params: { id: getIdFromGraphQLId(upstream.id) },
      });
    });

    it('does not render the edit button if `glAbilities.updateVirtualRegistry` is false', () => {
      createComponent({ provide: { glAbilities: { updateVirtualRegistry: false } } });
      expect(findEditButton().exists()).toBe(false);
    });

    it('renders the remove button if `glAbilities.destroyVirtualRegistry` is true', () => {
      expect(findRemoveButton().props('icon')).toBe('remove');
      expect(findRemoveButton().attributes('aria-label')).toBe('Remove upstream name');
    });

    it('does not render the remove button if `glAbilities.destroyVirtualRegistry` is false', () => {
      createComponent({ provide: { glAbilities: { destroyVirtualRegistry: false } } });
      expect(findRemoveButton().exists()).toBe(false);
    });
  });

  describe('emits events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits `reorder-upstream.up` when reorder up button is clicked', () => {
      findReorderUpButton().vm.$emit('click');

      expect(wrapper.emitted('reorder-upstream')[0]).toEqual(['up', defaultProps.registryUpstream]);
    });

    it('emits `reorder-upstream.down` when reorder down button is clicked', () => {
      findReorderDownButton().vm.$emit('click');

      expect(wrapper.emitted('reorder-upstream')[0]).toEqual([
        'down',
        defaultProps.registryUpstream,
      ]);
    });

    it('emits `clear-cache` when clear cache button is clicked', () => {
      findClearCacheButton().vm.$emit('click');

      expect(wrapper.emitted('clear-cache')[0]).toEqual([defaultProps.registryUpstream.upstream]);
    });

    it('emits `remove-upstream` when delete button is clicked', () => {
      findRemoveButton().vm.$emit('click');

      expect(wrapper.emitted('remove-upstream')[0]).toEqual([defaultProps.registryUpstream.id]);
    });
  });
});
