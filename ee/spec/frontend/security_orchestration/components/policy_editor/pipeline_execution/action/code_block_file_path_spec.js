import {
  GlAlert,
  GlFormInput,
  GlSprintf,
  GlFormGroup,
  GlFormInputGroup,
  GlIcon,
  GlTruncate,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CodeBlockStrategySelector from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/code_block_strategy_selector.vue';
import CodeBlockFilePath from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/code_block_file_path.vue';
import SuffixSelector from 'ee/security_orchestration/components/policy_editor/pipeline_execution/suffix_selector.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import RefSelector from '~/vue_shared/components/ref/components/ref_selector.vue';
import {
  INJECT,
  OVERRIDE,
  SCHEDULE,
  SUFFIX_ON_CONFLICT,
  SUFFIX_NEVER,
  DEPRECATED_INJECT,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('CodeBlockFilePath', () => {
  let wrapper;

  const PROJECT_ID = 'gid://gitlab/Project/29';

  const createComponent = ({ propsData = {}, provide = {}, includeStubs = true } = {}) => {
    const stubs = includeStubs ? { GlSprintf, GlAlert } : {};

    wrapper = shallowMountExtended(CodeBlockFilePath, {
      propsData: {
        strategy: INJECT,
        ...propsData,
      },
      stubs,
      provide: {
        namespacePath: 'gitlab-org',
        namespaceType: NAMESPACE_TYPES.GROUP,
        rootNamespacePath: 'gitlab',
        ...provide,
      },
    });
  };

  const findFormInput = () => wrapper.findComponent(GlFormInput);
  const findFilePathInput = () => wrapper.findComponent(GlFormInputGroup);
  const findFilePathWrapper = () => wrapper.findComponent(GlFormGroup);
  const findGlSprintf = () => wrapper.findComponent(GlSprintf);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findGroupProjectsDropdown = () => wrapper.findComponent(GroupProjectsDropdown);
  const findStrategySelector = () => wrapper.findComponent(CodeBlockStrategySelector);
  const findRefSelector = () => wrapper.findComponent(RefSelector);
  const findPipelineExecutionRefSelector = () =>
    wrapper.findByTestId('pipeline-execution-ref-selector');
  const findTruncate = () => wrapper.findComponent(GlTruncate);
  const findSuffixEditor = () => wrapper.findComponent(SuffixSelector);
  const findScheduleAccessAlert = () =>
    wrapper.findComponentByTestId('schedule-access-setting-alert');

  describe('initial state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders file path', () => {
      expect(findFilePathWrapper().exists()).toBe(true);
      expect(findFilePathInput().exists()).toBe(true);
      expect(findFilePathInput().attributes().disabled).toBe('true');
      expect(findTruncate().props('text')).toBe('No project selected');
    });

    it('renders ref input', () => {
      expect(findFormInput().exists()).toBe(true);
    });

    it('renders projects dropdown', () => {
      expect(findGroupProjectsDropdown().exists()).toBe(true);
      expect(findGroupProjectsDropdown().props('multiple')).toBe(false);
    });
  });

  it('renders message for "inject_policy"', () => {
    createComponent({ includeStubs: false });
    expect(findGlSprintf().attributes('message')).toBe(
      '%{strategySelector}into the %{boldStart}.gitlab-ci.yml%{boldEnd} with the following %{boldStart}pipeline execution file%{boldEnd} from %{projectSelector}',
    );
  });

  it('renders message for "inject_ci"', () => {
    createComponent({ propsData: { strategy: DEPRECATED_INJECT }, includeStubs: false });
    expect(findGlSprintf().attributes('message')).toBe(
      '%{strategySelector}into the %{boldStart}.gitlab-ci.yml%{boldEnd} with the following %{boldStart}pipeline execution file%{boldEnd} from %{projectSelector}',
    );
  });

  it('renders message for "override_project_ci"', () => {
    createComponent({ propsData: { strategy: OVERRIDE }, includeStubs: false });
    expect(findGlSprintf().attributes('message')).toBe(
      '%{strategySelector}the %{boldStart}.gitlab-ci.yml%{boldEnd} with the following %{boldStart}pipeline execution file%{boldEnd} from %{projectSelector}',
    );
  });

  it('renders message for "schedule"', () => {
    createComponent({ propsData: { strategy: SCHEDULE }, includeStubs: false });
    expect(findGlSprintf().attributes('message')).toBe(
      '%{strategySelector} pipeline file to run from %{projectSelector}',
    );
  });

  describe('information icon', () => {
    it('renders the help icon', () => {
      createComponent();
      expect(findIcon().exists()).toBe(true);
    });

    it('renders icon tooltip message for "inject_policy"', () => {
      createComponent();
      expect(findIcon().attributes('title')).toBe(
        'The content of this pipeline execution YAML file is injected into the .gitlab-ci.yml file of the target project. All GitLab CI/CD features are supported.',
      );
    });

    it('renders icon tooltip message for "inject_ci"', () => {
      createComponent({ propsData: { strategy: DEPRECATED_INJECT } });
      expect(findIcon().attributes('title')).toBe(
        'The content of this pipeline execution YAML file is injected into the .gitlab-ci.yml file of the target project. Custom stages used in the pipeline execution YAML are ignored, unless they are defined in the `.gitlab-ci.yml` file of the target project. All GitLab CI/CD features are supported.',
      );
    });

    it('renders icon tooltip message for "override_project_ci"', () => {
      createComponent({ propsData: { strategy: OVERRIDE } });
      expect(findIcon().attributes('title')).toBe(
        'The content of this pipeline execution YAML file overrides the .gitlab-ci.yml file of the target project. All GitLab CI/CD features are supported.',
      );
    });

    it('renders icon tooltip message for "schedule"', () => {
      createComponent({ propsData: { strategy: SCHEDULE } });
      expect(findIcon().attributes('title')).toBe(
        'The content of this pipeline execution YAML file of the target project is run at the scheduled time. All GitLab CI/CD features are supported.',
      );
    });
  });

  it('renders ref selector', () => {
    createComponent();
    expect(findRefSelector().exists()).toBe(false);
    expect(findPipelineExecutionRefSelector().exists()).toBe(true);
  });

  describe('selected state', () => {
    it('render selected ref input', () => {
      createComponent({
        propsData: {
          selectedRef: 'ref',
        },
      });

      expect(findRefSelector().exists()).toBe(false);
      expect(findFormInput().exists()).toBe(true);
      expect(findFormInput().attributes('value')).toBe('ref');
    });

    it('renders selected file path', () => {
      createComponent({
        propsData: {
          filePath: 'filePath',
        },
      });

      expect(findFilePathInput().attributes('value')).toBe('filePath');
    });

    it('has fallback values', () => {
      createComponent({
        propsData: {
          selectedProject: {},
        },
      });

      expect(findRefSelector().exists()).toBe(false);
      expect(findFormInput().exists()).toBe(true);
      expect(findGroupProjectsDropdown().props('selected')).toEqual([]);
    });

    it('renders selected override', () => {
      createComponent({ propsData: { strategy: OVERRIDE } });
      expect(findStrategySelector().props('strategy')).toBe(OVERRIDE);
    });
  });

  describe('actions', () => {
    it('can select ref', () => {
      createComponent();

      findFormInput().vm.$emit('input', 'ref');

      expect(wrapper.emitted('select-ref')).toEqual([['ref']]);
    });

    it('can select ref with selector', () => {
      createComponent({
        propsData: {
          selectedProject: {
            id: PROJECT_ID,
          },
        },
      });

      findRefSelector().vm.$emit('input', 'ref');

      expect(wrapper.emitted('select-ref')).toEqual([['ref']]);
    });

    it('can select project', () => {
      createComponent();

      findGroupProjectsDropdown().vm.$emit('select', PROJECT_ID);

      expect(wrapper.emitted('select-project')).toEqual([[PROJECT_ID]]);
    });

    it('can select file path', () => {
      createComponent();

      findFilePathInput().vm.$emit('input', 'file-path');

      expect(wrapper.emitted('update-file-path')).toEqual([['file-path']]);
    });

    it('can select strategy', () => {
      createComponent({ propsData: { strategy: INJECT } });
      findStrategySelector().vm.$emit('select', OVERRIDE);
      expect(wrapper.emitted('select-strategy')).toEqual([[OVERRIDE]]);
    });
  });

  describe('group projects dropdown', () => {
    it('uses namespace for a group as path', () => {
      createComponent();

      expect(findGroupProjectsDropdown().props('groupFullPath')).toBe('gitlab-org');
    });

    it('uses rootNamespace for a project as path', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(findGroupProjectsDropdown().props('groupFullPath')).toBe('gitlab');
    });
  });

  describe('validation', () => {
    describe('project and ref selectors', () => {
      it.each`
        title                                                         | filePath | doesFileExist | output
        ${'is valid when the file path is not provided'}              | ${null}  | ${false}      | ${true}
        ${'is valid when the file at the file path exists'}           | ${'ref'} | ${true}       | ${true}
        ${'is invalid when the file at the file path does not exist'} | ${'ref'} | ${false}      | ${false}
      `('$title', ({ filePath, doesFileExist, output }) => {
        createComponent({
          propsData: {
            filePath,
            doesFileExist,
            selectedProject: { id: PROJECT_ID },
          },
        });
        expect(findRefSelector().props('state')).toBe(output);
        expect(findGroupProjectsDropdown().props('state')).toBe(output);
      });
    });

    describe('file path selector', () => {
      it.each`
        title                                                         | filePath | doesFileExist | state        | message
        ${'is valid when the file path is not provided initially'}    | ${null}  | ${false}      | ${'true'}    | ${"The file path can't be empty"}
        ${'is valid when the file exists at the file path'}           | ${'ref'} | ${true}       | ${'true'}    | ${''}
        ${'is invalid when the file does not exist at the file path'} | ${'ref'} | ${false}      | ${undefined} | ${"The file at that project, ref, and path doesn't exist"}
      `('$title', ({ filePath, doesFileExist, state, message }) => {
        createComponent({
          propsData: {
            filePath,
            doesFileExist,
          },
        });
        expect(findFilePathInput().attributes('state')).toBe(state);
        expect(findFilePathWrapper().attributes('state')).toBe(state);
        expect(findFilePathWrapper().attributes('invalid-feedback')).toBe(message);
      });

      it('is invalid when the file path is empty and has been modified by the user', async () => {
        createComponent({
          propsData: {
            filePath: null,
            doesFileExist: false,
          },
        });
        await findFilePathInput().vm.$emit('input', '');
        expect(findFilePathInput().attributes('state')).toBe(undefined);
        expect(findFilePathWrapper().attributes('state')).toBe(undefined);
        expect(findFilePathWrapper().attributes('invalid-feedback')).toBe(
          "The file path can't be empty",
        );
      });
    });

    describe('schedule access setting alert', () => {
      const findProjectSettingsLink = () => wrapper.findByTestId('schedule-access-settings-link');
      const findAccessDocsLink = () => wrapper.findByTestId('schedule-access-docs-link');

      it('renders the alert when the schedule strategy is selected', () => {
        createComponent({ propsData: { strategy: SCHEDULE } });

        expect(findScheduleAccessAlert().props()).toMatchObject({
          variant: 'info',
          dismissible: false,
          title: 'Verify the file in the selected project is accessible',
        });
        expect(findScheduleAccessAlert().text()).toContain(
          'For this schedule to run, the selected project needs to allow this project access to its configuration files, with an allowed file pattern that matches the file path.',
        );
        expect(findProjectSettingsLink().exists()).toBe(false);
      });

      it('names the selected project and links to its settings', () => {
        createComponent({
          propsData: {
            strategy: SCHEDULE,
            selectedProject: { id: PROJECT_ID, fullPath: 'gitlab-org/security-project' },
          },
        });

        expect(findScheduleAccessAlert().text()).toContain(
          'For this schedule to run, gitlab-org/security-project needs to allow this project access to its configuration files, with an allowed file pattern that matches the file path.',
        );
        expect(findScheduleAccessAlert().text()).toContain(
          "Check with whoever owns that project's settings, or modify the settings directly.",
        );
        expect(findScheduleAccessAlert().find('strong').text()).toBe('gitlab-org/security-project');
        expect(findProjectSettingsLink().text()).toBe('settings');
        expect(findProjectSettingsLink().attributes('href')).toBe(
          '/gitlab-org/security-project/edit#js-shared-permissions',
        );
      });

      it('links to the access setting documentation', () => {
        createComponent({ propsData: { strategy: SCHEDULE } });

        expect(findAccessDocsLink().text()).toBe('Learn more.');
        expect(findAccessDocsLink().attributes('href')).toBe(
          '/help/user/application_security/policies/scheduled_pipeline_execution_policies#enable-access-to-cicd-configuration-files',
        );
      });

      it.each([INJECT, DEPRECATED_INJECT, OVERRIDE])(
        'does not render the alert for the "%s" strategy',
        (strategy) => {
          createComponent({ propsData: { strategy } });

          expect(findScheduleAccessAlert().exists()).toBe(false);
        },
      );
    });

    describe('suffix selector', () => {
      beforeEach(() => {
        createComponent({
          propsData: {
            suffix: SUFFIX_NEVER,
          },
        });
      });

      it('renders suffix selector', () => {
        expect(findSuffixEditor().props('suffix')).toBe(SUFFIX_NEVER);
      });

      it('emits event when suffix is changed', () => {
        findSuffixEditor().vm.$emit('update', SUFFIX_ON_CONFLICT);

        expect(wrapper.emitted('update-suffix')).toEqual([[SUFFIX_ON_CONFLICT]]);
      });
    });
  });
});
