import { GlEmptyState, GlLoadingIcon, GlLink } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DependenciesApp from 'ee/dependencies/components/app.vue';
import DependenciesActions from 'ee/dependencies/components/dependencies_actions.vue';
import SbomReportsErrorsAlert from 'ee/dependencies/components/sbom_reports_errors_alert.vue';
import DependencyExportDropdown from 'ee/dependencies/components/dependency_export_dropdown.vue';
import PaginatedDependenciesTable from 'ee/dependencies/components/paginated_dependencies_table.vue';
import createStore from 'ee/dependencies/store';
import { buildDefaultTrackedRefFilter } from 'ee/dependencies/components/filtered_search/utils';
import { TEST_HOST } from 'helpers/test_constants';
import { getDateInPast } from '~/lib/utils/datetime_utility';
import axios from '~/lib/utils/axios_utils';

describe('DependenciesApp component', () => {
  let store;
  let wrapper;
  let mock;

  const basicAppProvides = {
    hasDependencies: true,
    endpoint: '/foo',
    exportEndpoint: '/bar',
    emptyStateSvgPath: '/bar.svg',
    documentationPath: TEST_HOST,
    pageInfo: {},
    namespaceType: 'project',
    latestSuccessfulScanPath: '/group/project/-/pipelines/1',
    scanFinishedAt: getDateInPast(new Date(), 7),
    fullPath: '/group/project',
  };

  const basicProps = {
    sbomReportsErrors: [],
  };

  const factory = ({ provide, props, glFeatures = { groupDependenciesGraphQL: true } } = {}) => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();

    const stubs = Object.keys(DependenciesApp.components).filter((name) => name !== 'GlSprintf');

    wrapper = extendedWrapper(
      mount(DependenciesApp, {
        store,
        stubs,
        provide: { ...basicAppProvides, ...provide, glFeatures },
        propsData: { ...basicProps, ...props },
      }),
    );
  };

  const setStateLoaded = () => {
    const total = 2;
    Object.assign(store.state, {
      initialized: true,
      isLoading: false,
      dependencies: Array(total)
        .fill(null)
        .map((_, id) => ({ id })),
    });
    store.state.pageInfo.total = total;
  };

  const findDependenciesTables = () => wrapper.findAllComponents(PaginatedDependenciesTable);

  const findHeader = () => wrapper.find('section > header');
  const findExportMenu = () => wrapper.findComponent(DependencyExportDropdown);
  const findHeaderHelpLink = () => findHeader().findComponent(GlLink);
  const findHeaderScanLink = () => wrapper.findComponent({ ref: 'scanLink' });
  const findTimeAgoMessage = () => wrapper.findByTestId('time-ago-message');

  const expectComponentWithProps = (Component, props = {}) => {
    const componentWrapper = wrapper.findComponent(Component);
    expect(componentWrapper.isVisible()).toBe(true);
    expect(componentWrapper.props()).toEqual(expect.objectContaining(props));
  };

  const expectComponentPropsToMatchSnapshot = (Component) => {
    const componentWrapper = wrapper.findComponent(Component);
    expect(componentWrapper.props()).toMatchSnapshot();
  };

  const expectNoDependenciesTables = () => expect(findDependenciesTables()).toHaveLength(0);
  const expectNoHeader = () => expect(findHeader().exists()).toBe(false);

  const expectEmptyStateDescription = () => {
    expect(wrapper.html()).toContain(
      'The dependency list details information about the components used within your project.',
    );
  };

  const expectEmptyStateLink = () => {
    const emptyStateLink = wrapper.findComponent(GlLink);
    expect(emptyStateLink.html()).toContain('More Information');
    expect(emptyStateLink.attributes('href')).toBe(TEST_HOST);
    expect(emptyStateLink.attributes('target')).toBe('_blank');
  };

  const expectDependenciesTable = () => {
    const tables = findDependenciesTables();
    expect(tables).toHaveLength(1);
  };

  const expectHeader = () => {
    expect(findHeader().exists()).toBe(true);
  };

  describe('on creation', () => {
    beforeEach(() => {
      mock = new MockAdapter(axios);
      factory();
    });

    afterEach(() => {
      mock.restore();
    });

    it('dispatches the correct initial actions', () => {
      expect(store.dispatch.mock.calls).toEqual([
        ['setFullPath', basicAppProvides.fullPath],
        ['setDependenciesEndpoint', basicAppProvides.endpoint],
        ['setExportDependenciesEndpoint', basicAppProvides.exportEndpoint],
        ['setNamespaceType', basicAppProvides.namespaceType],
        ['setPageInfo', expect.anything()],
        ['setSortField', 'severity'],
        ['fetchDependenciesViaGraphQL'],
      ]);
    });

    describe('without export endpoint', () => {
      beforeEach(async () => {
        factory({ provide: { exportEndpoint: null } });
        setStateLoaded();

        await nextTick();
      });

      it('removes the export button', () => {
        expect(findExportMenu().exists()).toBe(false);
      });
    });

    describe('with namespaceType set to group', () => {
      beforeEach(() => {
        factory({ provide: { namespaceType: 'group' } });
      });

      it('dispatches setSortField with severity', () => {
        expect(store.dispatch.mock.calls).toEqual(
          expect.arrayContaining([['setSortField', 'severity']]),
        );
      });
    });

    it('shows only the loading icon', () => {
      expectComponentWithProps(GlLoadingIcon);
      expectNoHeader();
      expectNoDependenciesTables();
    });

    describe('if project has no dependencies', () => {
      beforeEach(async () => {
        factory({ provide: { hasDependencies: false } });
        setStateLoaded();

        await nextTick();
      });

      it('shows only the empty state', () => {
        expectComponentWithProps(GlEmptyState, { svgPath: basicAppProvides.emptyStateSvgPath });
        expectComponentPropsToMatchSnapshot(GlEmptyState);
        expectEmptyStateDescription();
        expectEmptyStateLink();
        expectNoHeader();
        expectNoDependenciesTables();
      });
    });

    describe('given a list of dependencies and ok report', () => {
      beforeEach(async () => {
        setStateLoaded();

        await nextTick();
      });

      it('shows the dependencies table with the correct props', () => {
        expectHeader();
        expectDependenciesTable();
      });

      it('renders export button', () => {
        const exportMenu = findExportMenu();
        expect(exportMenu.exists()).toBe(true);
        expect(exportMenu.props()).toHaveProperty('container', basicAppProvides.namespaceType);
      });

      describe('with namespaceType set to group', () => {
        beforeEach(async () => {
          factory({ provide: { namespaceType: 'group' } });

          await nextTick();
        });

        it('does not show a link to the latest scan', () => {
          expect(findHeaderScanLink().exists()).toBe(false);
        });

        it('does not show when the last scan ran', () => {
          expect(findTimeAgoMessage().exists()).toBe(false);
        });
      });

      it('shows a link to the latest scan', () => {
        expect(findHeaderScanLink().attributes('href')).toBe('/group/project/-/pipelines/1');
      });

      it('shows when the last scan ran', () => {
        expect(findTimeAgoMessage().text()).toBe('• 1 week ago');
      });

      it('shows a link to the dependencies documentation page', () => {
        expect(findHeaderHelpLink().attributes('href')).toBe(TEST_HOST);
      });

      it('passes the correct namespace to dependencies actions component', () => {
        expectComponentWithProps(DependenciesActions);
      });

      describe('where there is no pipeline info', () => {
        beforeEach(async () => {
          factory({
            provide: {
              latestSuccessfulScanPath: null,
              scanFinishedAt: null,
            },
          });
          setStateLoaded();

          await nextTick();
        });

        it('shows the header', () => {
          expectHeader();
        });

        it('does not show when the last scan ran', () => {
          expect(findHeader().text()).not.toContain('1 week ago');
        });

        it('does not show a link to the latest scan', () => {
          expect(findHeaderScanLink().exists()).toBe(false);
        });
      });
    });

    describe('given SBOM report errors are present', () => {
      const sbomErrors = [['Invalid SBOM report']];

      beforeEach(async () => {
        factory({
          props: { sbomReportsErrors: sbomErrors },
        });
        setStateLoaded();

        await nextTick();
      });

      it('passes the correct props to the sbom-report-errort alert', () => {
        expectComponentWithProps(SbomReportsErrorsAlert, {
          errors: sbomErrors,
        });
      });

      it('shows the dependencies table with the correct props', expectDependenciesTable);
    });
  });

  describe('default filters on load', () => {
    const defaultBranchContext = {
      id: 'gid://gitlab/Security::ProjectTrackedContext/23',
      name: 'main',
    };

    const trackedRefEnabled = {
      provide: {
        projectFullPath: 'gitlab-org/my-project',
        defaultBranchContext,
      },
      glFeatures: {
        groupDependenciesGraphQL: true,
        vulnerabilitiesAcrossContexts: true,
        projectDependencyTrackedRef: true,
      },
    };

    it('applies the default tracked ref filter when enabled', () => {
      factory(trackedRefEnabled);

      expect(store.dispatch).toHaveBeenCalledWith(
        'setSearchFilterParameters',
        buildDefaultTrackedRefFilter(defaultBranchContext),
      );
    });

    it('does not apply a default tracked ref filter when there is no default branch context', () => {
      factory({
        ...trackedRefEnabled,
        provide: { projectFullPath: 'gitlab-org/my-project', defaultBranchContext: null },
      });

      expect(store.dispatch).not.toHaveBeenCalledWith(
        'setSearchFilterParameters',
        expect.anything(),
      );
    });
  });

  describe.each(['groupDependenciesGraphQL'])(
    'with "%s" feature flag disabled',
    (featureFlagName) => {
      beforeEach(() => {
        mock = new MockAdapter(axios);
        factory({
          provide: { namespaceType: 'group' },
          glFeatures: { [featureFlagName]: false },
        });
      });

      it('dispatches the correct initial actions', () => {
        expect(store.dispatch.mock.calls).toEqual([
          ['setFullPath', basicAppProvides.fullPath],
          ['setDependenciesEndpoint', basicAppProvides.endpoint],
          ['setExportDependenciesEndpoint', basicAppProvides.exportEndpoint],
          ['setNamespaceType', 'group'],
          ['setPageInfo', expect.anything()],
          ['setSortField', 'severity'],
          ['fetchDependencies', { page: 1 }],
        ]);
      });
    },
  );
});
