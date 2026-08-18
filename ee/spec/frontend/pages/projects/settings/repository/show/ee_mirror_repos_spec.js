import $ from 'jquery';
import 'vendor/bootstrap/js/src/collapse';
import MockAdapter from 'axios-mock-adapter';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import waitForPromises from 'helpers/wait_for_promises';
import { createLegacyTable } from 'jest/mirrors/mock_data';
import EEMirrorRepos from 'ee/pages/projects/settings/repository/show/ee_mirror_repos';
import axios from '~/lib/utils/axios_utils';
import SSHMirror from '~/mirrors/ssh_mirror';

jest.mock('~/mirrors/ssh_mirror');

describe('EEMirrorRepos', () => {
  let mirrorRepos;
  let mockAxios;

  const createDirectionForm = () => `
    <div class="js-form-insertion-point"></div>
    <template class="js-push-mirrors-form">
      <input class="js-mirror-url-hidden" />
      <input class="js-mirror-protected-hidden" />
      <input class="js-mirror-branch-regex-hidden" />
      <input class="js-mirror-keep-divergent-refs" type="checkbox" value="1" />
      <input class="js-mirror-keep-divergent-refs-hidden" />
      <select class="js-auth-method"><option value="password">Password</option></select>
      <div class="js-password-group"><input class="js-password" /></div>
    </template>
    <template class="js-pull-mirrors-form">
      <input class="js-mirror-url-hidden" />
      <input class="js-mirror-protected-hidden" />
      <input class="js-mirror-branch-regex-hidden" />
    </template>
  `;

  const createMirrorForm = ({ mirrorDirectionDisabled = false } = {}) => `
    <form class="js-mirror-form" data-project-mirror-endpoint="/mirror" data-mirror-only-branches-match-regex-enabled="true">
      <input class="js-mirror-url js-repo-url" value="https://example.com/repository.git" />
      <select class="js-mirror-direction" ${mirrorDirectionDisabled ? 'disabled' : ''}>
        <option value="push">Push</option>
        <option value="pull">Pull</option>
      </select>
      ${createDirectionForm()}
      <input class="js-mirror-branch-setting" type="radio" name="mirror_branch_setting" value="all" checked />
      <input class="js-mirror-branch-setting" type="radio" name="mirror_branch_setting" value="protected" />
      <input class="js-mirror-branch-setting" type="radio" name="mirror_branch_setting" value="regex" />
      <input class="js-mirror-branch-regex" value="main|release.*" disabled />
      <input class="js-mirror-password-field" />
    </form>
  `;

  const createContainer = ({
    hasLegacyTable = false,
    isPullMirror = false,
    mirrorDirectionDisabled = false,
  } = {}) => {
    setHTMLFixture(
      `<div class="js-mirror-settings">${createMirrorForm({ mirrorDirectionDisabled })}${
        hasLegacyTable ? createLegacyTable({ isPullMirror }) : ''
      }</div>`,
    );
    return document.querySelector('.js-mirror-settings');
  };

  const createSubject = ({
    hasLegacyTable = false,
    isPullMirror = false,
    mirrorDirectionDisabled = false,
  } = {}) => {
    mirrorRepos = new EEMirrorRepos(
      createContainer({ hasLegacyTable, isPullMirror, mirrorDirectionDisabled }),
    );
    jest.spyOn(mirrorRepos, 'deleteMirror');
    jest.spyOn(mirrorRepos, 'registerTableListeners');
    mirrorRepos.init();
  };

  const findMirrorDirectionSelect = () => document.querySelector('.js-mirror-direction');
  const findMirrorUrlInput = () => document.querySelector('.js-mirror-url');
  const findMirrorUrlHiddenInput = () => document.querySelector('.js-mirror-url-hidden');
  const findProtectedBranchesHiddenInput = () =>
    document.querySelector('.js-mirror-protected-hidden');
  const findBranchRegexInput = () => document.querySelector('.js-mirror-branch-regex');
  const findBranchRegexHiddenInput = () => document.querySelector('.js-mirror-branch-regex-hidden');
  const findBranchSettingInput = (value) =>
    document.querySelector(`.js-mirror-branch-setting[value="${value}"]`);
  const findDeleteMirrorButton = () => document.querySelector('.js-delete-mirror');

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
    jest.spyOn($.fn, 'collapse').mockImplementation(function collapse(action) {
      if (action === 'hide') this.trigger('hidden.bs.collapse');
      if (action === 'show') this.trigger('shown.bs.collapse');

      return this;
    });

    SSHMirror.mockImplementation(() => ({
      destroy: jest.fn(),
      init: jest.fn(),
    }));
  });

  afterEach(() => {
    mockAxios.restore();
    jest.restoreAllMocks();
    resetHTMLFixture();
  });

  it('initializes form and branch settings when the legacy table is absent', async () => {
    createSubject();
    await waitForPromises();

    findMirrorUrlInput().value = 'https://example.com/updated.git';
    $(findMirrorUrlInput()).trigger('input');
    findBranchRegexInput().disabled = false;
    $(findBranchRegexInput()).trigger('change');
    findBranchSettingInput('protected').checked = true;
    $(findBranchSettingInput('protected')).trigger('change');
    jest.runOnlyPendingTimers();

    expect(findMirrorUrlHiddenInput().value).toBe('https://example.com/updated.git');
    expect(findBranchRegexHiddenInput().value).toBe('main|release.*');
    expect(findProtectedBranchesHiddenInput().value).toBe('1');
  });

  describe('legacy table listeners', () => {
    it('binds delete mirror clicks when the legacy table is present', async () => {
      createSubject({ hasLegacyTable: true });
      await waitForPromises();
      mockAxios.onPut('/mirror').reply(200, {});

      $(findDeleteMirrorButton()).trigger('click');
      await waitForPromises();

      expect(mirrorRepos.deleteMirror).toHaveBeenCalledTimes(1);
      expect(document.querySelector('.js-mirrors-table-body tr')).toBeNull();
      expect(document.querySelector('.js-mirrored-repo-count').textContent).toBe('1');
    });

    it('deletes a pull mirror and enables mirror direction selection', async () => {
      createSubject({
        hasLegacyTable: true,
        isPullMirror: true,
        mirrorDirectionDisabled: true,
      });
      await waitForPromises();
      mockAxios.onPut('/mirror').reply(200, {});

      $(findDeleteMirrorButton()).trigger('click');
      await waitForPromises();

      expect(JSON.parse(mockAxios.history.put[0].data)).toEqual({ project: { mirror: false } });
      expect(findMirrorDirectionSelect().hasAttribute('disabled')).toBe(false);
    });

    it('does not register table listeners when the legacy table is absent at init', () => {
      createSubject();

      expect(mirrorRepos.registerTableListeners).not.toHaveBeenCalled();
    });
  });

  it('updates the form when mirror direction changes without the legacy table', async () => {
    createSubject();
    await waitForPromises();

    findMirrorDirectionSelect().value = 'pull';
    $(findMirrorDirectionSelect()).trigger('change');
    await waitForPromises();

    expect(document.querySelector('.js-mirror-keep-divergent-refs')).toBeNull();
    expect(findMirrorUrlHiddenInput().value).toBe('https://example.com/repository.git');
  });
});
