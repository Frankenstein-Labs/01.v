import { GlLink, GlSkeletonLoader, GlLoadingIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended, extendedWrapper } from 'helpers/vue_test_utils_helper';
import DependenciesTable from 'ee/dependencies/components/dependencies_table.vue';
import DependencyLicenseLinks from 'ee/dependencies/components/dependency_license_links.vue';
import DependencyVulnerabilities from 'ee/dependencies/components/dependency_vulnerabilities.vue';
import DependencyLocationCount from 'ee/dependencies/components/dependency_location_count.vue';
import DependencyProjectCount from 'ee/dependencies/components/dependency_project_count.vue';
import DependencyRefCount from 'ee/dependencies/components/dependency_ref_count.vue';
import DependencyLocation from 'ee/dependencies/components/dependency_location.vue';
import VulnerabilitiesPopover from 'ee/dependencies/components/vulnerabilities_popover.vue';
import stubChildren from 'helpers/stub_children';
import waitForPromises from 'helpers/wait_for_promises';
import DependencyPathDrawer from 'ee/dependencies/components/dependency_path_drawer.vue';
import { makeDependency } from './utils';

describe('DependenciesTable component', () => {
  let wrapper;
  const vulnerabilityInfo = {
    1: ['bar', 'baz'],
  };

  const basicAppProps = {
    namespaceType: 'project',
    endpoint: 'endpoint',
    fullPath: 'test-group',
    projectFullPath: 'test-group/test-project',
  };

  const createComponent = ({ propsData, provide } = {}) => {
    wrapper = mountExtended(DependenciesTable, {
      propsData: { vulnerabilityInfo: {}, ...propsData },
      stubs: {
        ...stubChildren(DependenciesTable),
        GlTable: false,
        DependencyLocation: false,
        DependencyProjectCount: false,
        DependencyLocationCount: false,
      },
      provide: {
        glFeatures: { maliciousPackageDetection: true },
        ...basicAppProps,
        ...provide,
      },
    });
  };

  const findTableRows = () => wrapper.findAll('tbody > tr');
  const findRowToggleButtons = () => wrapper.findAllComponentsByTestId('row-toggle-button');
  const findDependencyVulnerabilities = () => wrapper.findComponent(DependencyVulnerabilities);
  const findDependencyLocation = () => wrapper.findComponent(DependencyLocation);
  const findDependencyLocationCount = () => wrapper.findComponent(DependencyLocationCount);
  const findDependencyProjectCount = () => wrapper.findComponent(DependencyProjectCount);
  const findDependencyRefCount = () => wrapper.findComponent(DependencyRefCount);
  const findHeaderLabels = () => wrapper.findAll('thead th').wrappers.map((w) => w.text());
  const findDependencyPathButtons = () => wrapper.findAllByTestId('dependency-path-button');
  const findDependencyPathDrawer = () => wrapper.findComponent(DependencyPathDrawer);
  const findPolicyViolationBadge = () => wrapper.findByTestId('policy-violation-badge');
  const findDependencyLicenseLinks = (licenseCell) =>
    licenseCell.findComponent(DependencyLicenseLinks);
  const findVulnerabilityPopover = () => wrapper.findComponent(VulnerabilitiesPopover);
  const normalizeWhitespace = (string) => string.replace(/\s+/g, ' ');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findCell = (rowWrapper, column) => rowWrapper.find(`[data-testid="${column}-cell"]`);
  const expectSharedCells = (rowWrapper, dependency) => {
    expect(normalizeWhitespace(findCell(rowWrapper, 'component').text())).toBe(
      `${dependency.name} ${dependency.version}`,
    );

    expect(findCell(rowWrapper, 'packager').text()).toBe(dependency.packager);

    expect(findDependencyLicenseLinks(findCell(rowWrapper, 'license')).props()).toEqual({
      licenses: dependency.licenses,
      title: dependency.name,
    });
  };
  const expectProjectRowCells = (rowWrapper, dependency) => {
    expectSharedCells(rowWrapper, dependency);

    expect(findDependencyLocation().exists()).toBe(true);
    const locationLink = findCell(rowWrapper, 'location').findComponent(GlLink);
    expect(locationLink.attributes().href).toBe(dependency.location.blobPath);
    expect(locationLink.text()).toContain(dependency.location.path);

    expect(findDependencyLocationCount().exists()).toBe(false);
    expect(findDependencyProjectCount().exists()).toBe(false);
  };

  const expectProjectRow = (rowWrapper, dependency) => {
    expectProjectRowCells(rowWrapper, dependency);

    const riskCellText = normalizeWhitespace(findCell(rowWrapper, 'risk').text());

    if (dependency?.vulnerabilities?.length) {
      expect(riskCellText).toContain(`${dependency.vulnerabilities.length} vuln`);
    } else {
      expect(riskCellText).toBe('');
    }
  };

  const expectProjectRowWithSbom = (rowWrapper, dependency) => {
    expectProjectRowCells(rowWrapper, dependency);

    const riskCellText = normalizeWhitespace(findCell(rowWrapper, 'risk').text());
    const vulns = vulnerabilityInfo[dependency.occurrenceId];

    if (vulns?.length) {
      expect(riskCellText).toContain(`${vulns.length} vuln`);
    } else {
      expect(riskCellText).toBe('');
    }
  };

  const expectGroupRow = (rowWrapper, dependency) => {
    expectSharedCells(rowWrapper, dependency);

    const { occurrenceCount, projectCount } = dependency;

    const riskCellText = normalizeWhitespace(findCell(rowWrapper, 'risk').text());
    const vulns = vulnerabilityInfo[dependency.occurrenceId];

    if (vulns?.length) {
      expect(riskCellText).toContain(`${vulns.length} vuln`);
    } else {
      expect(riskCellText).toBe('');
    }
    expect(findCell(rowWrapper, 'location').text()).toContain(occurrenceCount.toString());
    expect(findCell(rowWrapper, 'projects').text()).toContain(projectCount.toString());
  };

  describe('given the table is loading', () => {
    let dependencies;

    beforeEach(() => {
      dependencies = [makeDependency()];
      createComponent({
        propsData: {
          dependencies,
          isLoading: true,
        },
      });
    });

    it('renders the loading skeleton', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    it('does not render any dependencies', () => {
      expect(wrapper.text()).not.toContain(dependencies[0].name);
    });
  });

  describe('given an empty list of dependencies', () => {
    describe.each`
      namespaceType | expectedLabels
      ${'project'}  | ${['Component', 'Packager', 'Location', 'License', 'Risk']}
      ${'group'}    | ${['Component', 'Packager', 'Location', 'License', 'Projects', 'Risk']}
    `('with namespaceType set to "$namespaceType"', ({ namespaceType, expectedLabels }) => {
      beforeEach(() => {
        createComponent({
          propsData: {
            dependencies: [],
            isLoading: false,
          },
          provide: {
            namespaceType,
          },
        });
      });

      it('renders the table header', () => {
        const headerCells = wrapper.findAll('thead th');

        expectedLabels.forEach((expectedLabel, i) => {
          expect(headerCells.at(i).text()).toContain(expectedLabel);
        });
      });

      it('renders vulnerability popover', () => {
        expect(findVulnerabilityPopover().exists()).toBe(true);
      });

      it('renders a message that there are no records to show', () => {
        expect(wrapper.text()).toContain('There are no records to show');
      });
    });
  });

  describe('row rendering', () => {
    describe('project', () => {
      describe.each`
        description                                                             | vulnerabilitiesPayload
        ${'given dependencies with no vulnerabilities'}                         | ${{ vulnerabilities: [] }}
        ${'given dependencies when user is not allowed to see vulnerabilities'} | ${{}}
      `('$description', ({ vulnerabilitiesPayload }) => {
        let dependencies;

        beforeEach(() => {
          dependencies = [
            makeDependency({ ...vulnerabilitiesPayload }),
            makeDependency({ name: 'foo', ...vulnerabilitiesPayload }),
          ];

          createComponent({
            propsData: {
              dependencies,
              isLoading: false,
            },
          });
        });

        it('renders a row for each dependency', () => {
          const rows = findTableRows();

          dependencies.forEach((dependency, i) => {
            expectProjectRow(rows.at(i), dependency);
          });
        });

        it('does not render any row toggle buttons', () => {
          expect(findRowToggleButtons()).toHaveLength(0);
        });

        it('does not render vulnerability details', () => {
          expect(findDependencyVulnerabilities().exists()).toBe(false);
        });
      });

      describe('given some dependencies with vulnerabilities', () => {
        let dependencies;

        beforeEach(() => {
          dependencies = [
            makeDependency({
              name: 'qux',
              vulnerabilities: ['bar', 'baz'],
              vulnerabilityCount: 2,
              occurrenceId: 1,
            }),
            makeDependency({ vulnerabilities: [], vulnerabilityCount: 0, occurrenceId: 2 }),
            // Guarantee that the component doesn't mutate these, but still
            // maintains its row-toggling behaviour (i.e., via _showDetails)
          ].map(Object.freeze);

          createComponent({
            propsData: {
              dependencies,
              isLoading: false,
              vulnerabilityInfo,
            },
          });
        });

        it('renders a row for each dependency', () => {
          const rows = findTableRows();

          dependencies.forEach((dependency, i) => {
            expectProjectRowWithSbom(rows.at(i), dependency);
          });
        });

        it('renders the toggle button for each row', () => {
          const toggleButtons = findRowToggleButtons();

          dependencies.forEach((dependency, i) => {
            const button = toggleButtons.at(i);

            expect(button.exists()).toBe(true);
            expect(button.classes('gl-invisible')).toBe(dependency.vulnerabilityCount === 0);
          });
        });

        it('does not render vulnerability details', () => {
          expect(findDependencyVulnerabilities().exists()).toBe(false);
        });
      });
    });

    describe('group', () => {
      describe('with multiple dependencies sharing the same componentId', () => {
        let dependencies;
        beforeEach(() => {
          dependencies = [
            makeDependency({
              componentId: 1,
              occurrenceCount: 2,
              project: { full_path: 'full_path', name: 'name' },
              projectCount: 2,
            }),
            makeDependency({
              componentId: 1,
              occurrenceCount: 2,
              project: { full_path: 'full_path', name: 'name' },
              projectCount: 2,
            }),
            makeDependency({
              componentId: 2,
              occurrenceCount: 1,
              project: { full_path: 'full_path', name: 'name' },
              projectCount: 1,
            }),
          ];

          createComponent({
            propsData: {
              dependencies,
              isLoading: false,
            },
            provide: { namespaceType: 'group' },
          });
        });

        it('renders a row for each dependency', () => {
          const rows = findTableRows();
          expectGroupRow(rows.at(0), dependencies[0]);
          expectGroupRow(rows.at(1), dependencies[1]);
          expectGroupRow(rows.at(2), dependencies[2]);
        });
      });
    });
  });

  describe('packager column', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          dependencies: [
            makeDependency({
              componentId: 1,
              occurrenceCount: 1,
              project: { full_path: 'full_path', name: 'name' },
              projectCount: 1,
              packager: null,
            }),
          ],
          isLoading: false,
        },
      });
    });

    it('displays unknown when packager is not set', () => {
      expect(wrapper.findByTestId('packager-cell').text()).toBe('unknown');
    });
  });

  describe('refs column', () => {
    const mockTrackedRefsCount = 3;

    const createComponentWithRefs = ({ propsData, provide } = {}) => {
      createComponent({
        propsData: {
          dependencies: [makeDependency({ trackedRefsCount: mockTrackedRefsCount })],
          isLoading: false,
          ...propsData,
        },
        provide: {
          glFeatures: { vulnerabilitiesAcrossContexts: true, projectDependencyTrackedRef: true },
          projectFullPath: 'group/project',
          ...provide,
        },
      });
    };

    it('renders the "Refs" header for a project namespace', () => {
      createComponentWithRefs();

      expect(findHeaderLabels()).toContain('Refs');
    });

    it('renders DependencyRefCount with the trackedRefsCount prop', () => {
      createComponentWithRefs();

      expect(findDependencyRefCount().props('trackedRefsCount')).toBe(mockTrackedRefsCount);
    });

    it.each`
      scenario                        | provide
      ${'the namespace is a group'}   | ${{ namespaceType: 'group' }}
      ${'projectFullPath is missing'} | ${{ projectFullPath: '' }}
    `('does not render the "Refs" header when $scenario', ({ provide }) => {
      createComponentWithRefs({ provide });

      expect(findHeaderLabels()).not.toContain('Refs');
    });

    it.each`
      scenario                                       | glFeatures
      ${'vulnerabilitiesAcrossContexts is disabled'} | ${{ vulnerabilitiesAcrossContexts: false, projectDependencyTrackedRef: true }}
      ${'projectDependencyTrackedRef is disabled'}   | ${{ vulnerabilitiesAcrossContexts: true, projectDependencyTrackedRef: false }}
      ${'both FFs are disabled'}                     | ${{ vulnerabilitiesAcrossContexts: false, projectDependencyTrackedRef: false }}
    `('does not render the "Refs" header when $scenario', ({ glFeatures }) => {
      createComponentWithRefs({ provide: { glFeatures } });

      expect(findHeaderLabels()).not.toContain('Refs');
    });
  });

  describe('location column', () => {
    describe('project', () => {
      const dependency = makeDependency({
        occurrenceId: 1,
      });

      beforeEach(() => {
        createComponent({
          propsData: {
            dependencies: [dependency],
            isLoading: false,
          },
        });
      });

      it('passes the correct prop to the DependencyPathDrawer component when triggered', async () => {
        const { name, version } = dependency;

        findDependencyLocation().vm.$emit('click-dependency-path');

        await nextTick();

        expect(findDependencyPathDrawer().props()).toMatchObject({
          showDrawer: true,
          component: { name, version },
          occurrenceId: 1,
        });
      });
    });

    describe('group', () => {
      const dependency = makeDependency({
        componentId: 1,
        occurrenceCount: 2,
        occurrenceId: 1,
        project: { full_path: 'full_path', name: 'name' },
      });

      beforeEach(() => {
        createComponent({
          propsData: {
            dependencies: [dependency],
            isLoading: false,
          },
        });
      });

      it('does not display the dependency path button', () => {
        expect(findDependencyPathButtons()).toHaveLength(0);
      });

      it('passes the correct props and only locations with dependency paths to the DependencyPathDrawer component when triggered', async () => {
        const { name, version } = dependency;
        const emittedItem = [
          {
            project: { name: 'emitted-project', fullPath: 'group-1/emitted-project' },
            occurrenceId: 1,
            hasDependencyPaths: true,
          },
          {
            project: { name: 'emitted-project-2', fullPath: 'group-1/emitted-project-2' },
            occurrenceId: 2,
            hasDependencyPaths: false,
          },
        ];

        findDependencyLocationCount().vm.$emit('click-dependency-path', emittedItem);

        await nextTick();

        expect(findDependencyPathDrawer().props()).toMatchObject({
          showDrawer: true,
          component: { name, version },
          dropdownItems: [
            { value: 1, text: 'emitted-project', fullPath: 'group-1/emitted-project' },
          ],
          occurrenceId: 1,
        });
      });
    });
  });

  describe('risk column', () => {
    describe('malware badge', () => {
      const dependencies = [
        { name: 'malicious-pkg', malware: true, occurrenceId: 1 },
        { name: 'safe-pkg', malware: false, occurrenceId: 2 },
      ];
      const createMalwareDependencies = () => dependencies.map(makeDependency);

      const findMalwareBadge = () => wrapper.findByTestId('malware-badge');

      beforeEach(() => {
        createComponent({
          propsData: {
            dependencies: createMalwareDependencies(),
            isLoading: false,
          },
        });
      });

      it('displays the malware badge for dependencies flagged as malware', () => {
        expect(findMalwareBadge().attributes('variant')).toBe('danger');
        expect(findMalwareBadge().attributes('icon')).toBe('bug');
      });

      it.each(dependencies)(
        'displays the malware badge for dependency: "$malware"',
        (dependency) => {
          const rowIndex = dependencies.indexOf(dependency);
          const row = extendedWrapper(findTableRows().at(rowIndex));

          expect(row.findByTestId('malware-badge').exists()).toBe(dependency.malware);
        },
      );

      it('does not display the malware badge for non-malware dependencies', () => {
        const malwareRow = extendedWrapper(findTableRows().at(0));
        const safeRow = extendedWrapper(findTableRows().at(1));

        expect(malwareRow.findByTestId('malware-badge').exists()).toBe(true);
        expect(safeRow.findByTestId('malware-badge').exists()).toBe(false);
      });

      it('shows a tooltip on the malware badge', () => {
        expect(findMalwareBadge().attributes('title')).toBe(
          'This package has been identified as malware',
        );
      });

      describe('when maliciousPackageDetection feature flag is disabled', () => {
        it('does not display the malware badge', () => {
          createComponent({
            propsData: {
              dependencies: createMalwareDependencies(),
              isLoading: false,
            },
            provide: {
              glFeatures: { maliciousPackageDetection: false },
            },
          });

          expect(findMalwareBadge().exists()).toBe(false);
        });
      });
    });

    describe('policy violation badge', () => {
      beforeEach(() => {
        const dependencies = [
          makeDependency({
            name: 'qux',
            vulnerabilities: { nodes: [{ id: 1, policyViolations: true }] },
            vulnerabilityCount: 1,
            occurrenceId: 1,
          }),
          makeDependency({
            name: 'qux',
            vulnerabilities: { nodes: [] },
            vulnerabilityCount: 0,
            occurrenceId: 1,
          }),
          // Guarantee that the component doesn't mutate these, but still
          // maintains its row-toggling behaviour (i.e., via _showDetails)
        ].map(Object.freeze);

        createComponent({
          propsData: {
            dependencies,
            isLoading: false,
            vulnerabilityInfo,
          },
        });
      });

      it('displays the policy violation badge for dependencies that violate a security policy', () => {
        const row = extendedWrapper(findTableRows().at(0));
        expect(row.findByTestId('policy-violation-badge').text()).toBe('Policy violation');
      });

      it('does not display the policy violation badge for dependencies that do not violate a security policy', () => {
        const row = extendedWrapper(findTableRows().at(1));
        expect(row.findByTestId('policy-violation-badge').exists()).toBe(false);
      });
    });

    describe('policy dismissals', () => {
      describe('given some dependencies with policy dismissals', () => {
        let dependencies;

        beforeEach(() => {
          dependencies = [
            makeDependency({
              name: 'lodash',
              occurrenceCount: 2,
              projectCount: 2,
              componentId: 1,
              policyDismissals: [
                { id: 1, projectId: 10, projectName: 'Project A', projectPath: 'group/project-a' },
                { id: 2, projectId: 11, projectName: 'Project B', projectPath: 'group/project-b' },
              ],
            }),
            makeDependency({
              name: 'express',
              occurrenceCount: 1,
              projectCount: 1,
              componentId: 2,
              policyDismissals: [],
            }),
          ].map(Object.freeze);

          createComponent({
            propsData: {
              dependencies,
              isLoading: false,
            },
            provide: { namespaceType: 'group' },
          });
        });

        it('displays the policy dismissal badge for dependencies with dismissals', () => {
          expect(findPolicyViolationBadge().exists()).toBe(true);
          expect(findPolicyViolationBadge().text()).toBe('Policy violation');
        });

        it('shows project names in the tooltip', () => {
          const tooltip = findPolicyViolationBadge().attributes('title');

          expect(tooltip).toContain('Project A');
          expect(tooltip).toContain('Project B');
        });

        it('does not display the badge for dependencies without dismissals', () => {
          const secondRow = findTableRows().at(1);
          const badges = secondRow.findAll('[data-testid="policy-violation-badge"]');

          expect(badges).toHaveLength(0);
        });

        it('renders a single policy violation badge when vulnerability policy violations and dismissals both exist', () => {
          createComponent({
            propsData: {
              dependencies: [
                makeDependency({
                  name: 'lodash',
                  occurrenceCount: 1,
                  projectCount: 1,
                  componentId: 1,
                  vulnerabilities: { nodes: [{ id: 1, policyViolations: true }] },
                  vulnerabilityCount: 1,
                  policyDismissals: [
                    {
                      id: 1,
                      projectId: 10,
                      projectName: 'Project A',
                      projectPath: 'group/project-a',
                    },
                  ],
                }),
              ],
              isLoading: false,
            },
            provide: { namespaceType: 'group' },
          });

          expect(wrapper.findAllByTestId('policy-violation-badge')).toHaveLength(1);
        });
      });

      describe('given dependencies with duplicate project names in policy dismissals', () => {
        beforeEach(() => {
          const dependencies = [
            makeDependency({
              name: 'lodash',
              occurrenceCount: 3,
              projectCount: 2,
              componentId: 1,
              policyDismissals: [
                { id: 1, projectId: 10, projectName: 'Project A', projectPath: 'group/project-a' },
                { id: 2, projectId: 10, projectName: 'Project A', projectPath: 'group/project-a' },
              ],
            }),
          ].map(Object.freeze);

          createComponent({
            propsData: {
              dependencies,
              isLoading: false,
            },
            provide: { namespaceType: 'group' },
          });
        });

        it('deduplicates project names in the tooltip', () => {
          const tooltip = findPolicyViolationBadge().attributes('title');
          const projectACount = (tooltip.match(/Project A/g) || []).length;

          expect(projectACount).toBe(1);
        });
      });
    });
  });

  describe('vulnerability details', () => {
    let dependencies;
    let rowIndexWithVulnerabilities;

    beforeEach(() => {
      dependencies = [
        makeDependency({
          name: 'qux',
          vulnerabilities: ['bar', 'baz'],
          vulnerabilityCount: 2,
          occurrenceId: 1,
        }),
        makeDependency({ vulnerabilities: [], vulnerabilityCount: 0, occurrenceId: 2 }),
        // Guarantee that the component doesn't mutate these, but still
        // maintains its row-toggling behaviour (i.e., via _showDetails)
      ].map(Object.freeze);

      createComponent({
        propsData: {
          dependencies,
          isLoading: false,
          vulnerabilityInfo,
        },
      });

      rowIndexWithVulnerabilities = dependencies.findIndex((dep) => dep.vulnerabilities.length > 0);
    });

    it('can be displayed by clicking on the toggle button', () => {
      const dependency = dependencies[rowIndexWithVulnerabilities];
      const vulnerabilities = vulnerabilityInfo[dependency.occurrenceId];
      const toggleButton = findRowToggleButtons().at(rowIndexWithVulnerabilities);
      toggleButton.vm.$emit('click');

      return nextTick().then(() => {
        expect(findDependencyVulnerabilities().props()).toEqual({
          vulnerabilities,
        });
      });
    });

    it('can be displayed by clicking on the vulnerabilities badge', () => {
      const dependency = dependencies[rowIndexWithVulnerabilities];
      const vulnerabilities = vulnerabilityInfo[dependency.occurrenceId];
      const row = extendedWrapper(findTableRows().at(rowIndexWithVulnerabilities));
      const badge = row.findComponentByTestId('vulnerability-badge');
      badge.vm.$emit('click');

      return nextTick().then(() => {
        expect(findDependencyVulnerabilities().props()).toEqual({
          vulnerabilities,
        });
      });
    });

    it('handles row-click event', () => {
      const toggleButton = findRowToggleButtons().at(rowIndexWithVulnerabilities);
      toggleButton.vm.$emit('click');

      return nextTick().then(() => {
        expect(wrapper.emitted('row-click')).toHaveLength(1);
      });
    });

    it('can display loading icon', async () => {
      const toggleButton = findRowToggleButtons().at(rowIndexWithVulnerabilities);
      toggleButton.vm.$emit('click');

      await waitForPromises();
      const events = wrapper.emitted('row-click');

      wrapper.setProps({ vulnerabilityItemsLoading: events[0] });
      await waitForPromises();
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });
});
