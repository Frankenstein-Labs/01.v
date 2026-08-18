import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectsToggleList from 'ee/security_orchestration/components/scope/projects_toggle_list.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import ToggleList from 'ee/security_orchestration/components/scope/toggle_list.vue';

describe('ProjectsToggleList', () => {
  let wrapper;

  const defaultNodes = [
    {
      id: convertToGraphQLId(TYPENAME_PROJECT, 1),
      name: '1',
      fullPath: 'project-1-full-path',
      repository: { rootRef: 'main' },
    },
    {
      id: convertToGraphQLId(TYPENAME_PROJECT, 2),
      name: '2',
      fullPath: 'project-2-full-path',
      repository: { rootRef: 'main' },
    },
  ];

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectsToggleList, {
      propsData: {
        projects: defaultNodes,
        ...propsData,
      },
    });
  };

  const findToggleList = () => wrapper.findComponent(ToggleList);
  const findHeader = () => wrapper.findByTestId('toggle-list-header');

  describe('all projects', () => {
    describe('many projects', () => {
      beforeEach(() => {
        createComponent({
          propsData: {
            projects: [],
          },
        });
      });

      it('should not render toggle list', () => {
        expect(findToggleList().exists()).toBe(false);
      });

      it('should render header for all projects', () => {
        expect(findHeader().text()).toBe('All projects in this group');
      });
    });

    describe('single project', () => {
      it('renders header and list for all projects when there is single project in the group', () => {
        createComponent({
          propsData: {
            projects: [defaultNodes[0]],
          },
        });

        expect(findHeader().text()).toBe('All projects in this group except:');
        expect(findToggleList().props('items')).toHaveLength(1);
      });

      it('renders header and list for all projects when there is single project in the instance', () => {
        createComponent({
          propsData: {
            isInstanceLevel: true,
            projects: [defaultNodes[0]],
          },
        });

        expect(findHeader().text()).toBe('All projects in this instance except:');
        expect(findToggleList().props('items')).toHaveLength(1);
      });
    });

    describe('personal project exclusions', () => {
      describe('only personal projects excluded', () => {
        beforeEach(() => {
          createComponent({
            propsData: {
              projects: [],
              including: false,
              excludingPersonalProjects: true,
            },
          });
        });

        it('should render the toggle list when only personal projects are excluded', () => {
          expect(findToggleList().exists()).toBe(true);
        });

        it('should render header for personal projects exclusion in group context', () => {
          expect(findHeader().text()).toBe('All projects in this group except:');
        });
      });

      describe('personal projects excluded with specific projects', () => {
        beforeEach(() => {
          createComponent({
            propsData: {
              projects: defaultNodes,
              including: false,
              excludingPersonalProjects: true,
            },
          });
        });

        it('should render toggle list with only actual projects (filtering out personal type)', () => {
          expect(findToggleList().exists()).toBe(true);
          expect(findToggleList().props('items')).toEqual(['personal projects', '1', '2']);
        });

        it('should render header indicating personal projects and specific projects are excluded', () => {
          expect(findHeader().text()).toBe('All projects in this group except:');
        });
      });

      describe('context-aware headers for personal project exclusions', () => {
        it('renders instance-level header for personal projects only', () => {
          createComponent({
            propsData: {
              projects: [],
              including: false,
              isInstanceLevel: true,
              excludingPersonalProjects: true,
            },
          });

          expect(findHeader().text()).toBe('All projects in this instance except:');
        });

        it('renders project-level header for personal projects only', () => {
          createComponent({
            propsData: {
              projects: [],
              including: false,
              isGroup: false,
              excludingPersonalProjects: true,
            },
          });

          expect(findHeader().text()).toBe('All projects linked to this project except:');
        });

        it('renders instance-level header for mixed exclusions', () => {
          createComponent({
            propsData: {
              projects: [defaultNodes[0]],
              including: false,
              isInstanceLevel: true,
              excludingPersonalProjects: true,
            },
          });

          expect(findHeader().text()).toBe('All projects in this instance except:');
        });
      });
    });
  });

  describe('specific projects', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          projects: [defaultNodes[0]],
          including: true,
        },
      });
    });

    it('should render toggle list with specific projects', () => {
      expect(findToggleList().exists()).toBe(true);
      expect(findToggleList().props('items')).toEqual(['1']);
    });

    it('should render header for specific projects', () => {
      expect(findHeader().text()).toBe('1 project:');
    });
  });

  describe('project level', () => {
    it('should render toggle list and specific header for all projects', () => {
      createComponent({
        propsData: {
          isGroup: false,
        },
      });

      expect(findToggleList().exists()).toBe(true);
      expect(findHeader().text()).toBe('All projects linked to this project except:');
    });

    it('should render toggle list and specific header for specific projects', () => {
      createComponent({
        propsData: {
          isGroup: false,
          including: true,
        },
      });

      expect(findToggleList().exists()).toBe(true);
      expect(findHeader().text()).toBe('2 projects:');
    });
  });

  describe('partial list', () => {
    it('renders partial lists for projects', () => {
      createComponent({
        propsData: {
          projectsToShow: 3,
          inlineList: true,
        },
      });

      expect(findToggleList().props('itemsToShow')).toBe(3);
      expect(findToggleList().props('inlineList')).toBe(true);
    });
  });
});
