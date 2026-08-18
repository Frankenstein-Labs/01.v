import { GlTableLite, GlButton } from '@gitlab/ui';
import containerRegistriesPayload from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_container_virtual_registries.query.graphql.json';
import mavenRegistriesPayload from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registries.query.graphql.json';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import RegistriesTable from 'ee/packages_and_registries/virtual_registries/components/common/registries/table.vue';
import ContainerRoutes from 'ee/packages_and_registries/virtual_registries/pages/container/routes';

describe('RegistriesTable', () => {
  let wrapper;

  const mavenProvide = {
    editRegistryPathTemplate: '/groups/gitlab-org/-/virtual_registries/maven/registries/:id/edit',
    showRegistryPathTemplate: '/groups/gitlab-org/-/virtual_registries/maven/registries/:id',
  };

  const containerProvide = {
    routes: ContainerRoutes,
  };

  describe.each`
    type           | registriesPayload             | providedValues      | routes
    ${'maven'}     | ${mavenRegistriesPayload}     | ${mavenProvide}     | ${{}}
    ${'container'} | ${containerRegistriesPayload} | ${containerProvide} | ${ContainerRoutes}
  `('$type virtual registry', ({ type, registriesPayload, providedValues, routes }) => {
    const { nodes: registries } = registriesPayload.data.group.registries;

    const defaultProps = {
      registries,
    };

    const [registry] = defaultProps.registries;
    const registryId = getIdFromGraphQLId(registry.id);

    const defaultProvide = {
      glAbilities: {
        updateVirtualRegistry: true,
      },
      ...providedValues,
    };

    const findTable = () => wrapper.findComponent(GlTableLite);
    const findRegistryLinks = () => wrapper.findAllComponentsByTestId('registry-name');
    const findEditButtons = () =>
      wrapper
        .findAllComponents(GlButton)
        .filter((w) => w.attributes('data-testid') === 'edit-registry-button');
    const findTimeAgoTooltips = () => wrapper.findAllComponents(TimeAgoTooltip);

    const createComponent = ({ props = {}, provide = {} } = {}) => {
      wrapper = mountExtended(RegistriesTable, {
        propsData: {
          ...defaultProps,
          ...props,
        },
        provide: {
          ...defaultProvide,
          ...provide,
        },
      });
    };

    describe('component rendering', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the table with correct fields', () => {
        expect(findTable().props('fields')).toEqual([
          {
            key: 'name',
            label: 'Registry',
            thClass: '!gl-border-t-0',
            tdClass: '@sm/panel:gl-max-w-0 !gl-py-3',
          },
          {
            key: 'updated',
            label: 'Last updated',
            thClass: 'gl-w-20 !gl-border-t-0',
            tdClass: '!gl-py-3',
          },
          {
            key: 'actions',
            label: 'Actions',
            hide: false,
            thClass: 'gl-w-6 gl-text-right !gl-border-t-0',
            tdClass: 'gl-text-right !gl-py-3',
          },
        ]);
      });

      it('renders registry names as links', () => {
        const links = findRegistryLinks();

        expect(links).toHaveLength(1);
        if (type === 'maven') {
          expect(links.at(0).attributes('href')).toBe(
            `/groups/gitlab-org/-/virtual_registries/${type}/registries/${registryId}`,
          );
        } else {
          expect(links.at(0).props('to')).toStrictEqual({
            name: routes.showRegistryRouteName,
            params: { id: registryId },
          });
        }
        expect(links.at(0).text()).toBe(registry.name);
      });

      it('displays updated date with TimeAgoTooltip', () => {
        const tooltips = findTimeAgoTooltips();

        expect(tooltips).toHaveLength(1);
        expect(tooltips.at(0).props('time')).toBe(registry.updatedAt);
      });

      it('renders edit button when user has permission', () => {
        const editButtons = findEditButtons();

        expect(editButtons).toHaveLength(1);
        expect(editButtons.at(0).props()).toMatchObject({
          size: 'small',
          category: 'tertiary',
          icon: 'pencil',
        });

        if (type === 'maven') {
          expect(editButtons.at(0).props('href')).toBe(
            `/groups/gitlab-org/-/virtual_registries/${type}/registries/${registryId}/edit`,
          );
        } else {
          expect(editButtons.at(0).props('to')).toEqual({
            name: routes.editRegistryRouteName,
            params: { id: registryId },
          });
        }
        expect(editButtons.at(0).attributes('aria-label')).toBe(`Edit registry ${registry.name}`);
      });

      describe('when user lacks permissions', () => {
        beforeEach(() => {
          createComponent({
            provide: {
              glAbilities: {
                updateVirtualRegistry: false,
              },
            },
          });
        });

        it('does not render edit button', () => {
          expect(findEditButtons()).toHaveLength(0);
        });

        it('hides the table action column', () => {
          expect(findTable().props('fields')).toEqual([
            {
              key: 'name',
              label: 'Registry',
              thClass: '!gl-border-t-0',
              tdClass: '@sm/panel:gl-max-w-0 !gl-py-3',
            },
            {
              key: 'updated',
              label: 'Last updated',
              thClass: 'gl-w-20 !gl-border-t-0',
              tdClass: '!gl-py-3',
            },
          ]);
        });
      });
    });

    describe('with empty registries array', () => {
      beforeEach(() => {
        createComponent({
          props: {
            registries: [],
          },
        });
      });

      it('renders table with no items', () => {
        expect(findTable().exists()).toBe(true);
        expect(findRegistryLinks()).toHaveLength(0);
        expect(findEditButtons()).toHaveLength(0);
      });
    });
  });
});
