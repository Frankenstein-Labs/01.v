import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import mountComponents from 'ee/registrations/groups/new';

const setup = () => {
  const fixture = `
    <div class="js-import-project-buttons">
      <a href="#" data-href="/import/gitlab_project" class="js-import-gitlab-project-btn">gitlab</a>
      <a href="/import/github" class="js-import-github">github</a>
    </div>

    <div class="js-import-project-form">
      <input type="hidden" class="js-import-url" />
      <input type="submit" />
    </form>
  `;
  setHTMLFixture(fixture);
  mountComponents();
};

describe('importButtonsSubmit', () => {
  beforeEach(() => {
    setup();
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  const findSubmit = () => document.querySelector('.js-import-project-form input[type="submit"]');
  const findImportUrlValue = () => document.querySelector('.js-import-url').value;
  const findImportGithubButton = () => document.querySelector('.js-import-github');
  const findImportGitlabButton = () => document.querySelector('.js-import-gitlab-project-btn');

  it('sets the import-url field with the value of the href and clicks submit for github', () => {
    const submitSpy = jest.spyOn(findSubmit(), 'click');
    findImportGithubButton().click();

    expect(findImportUrlValue()).toBe('/import/github');
    expect(submitSpy).toHaveBeenCalled();
  });

  it('sets the import-url field with the value of the href and clicks submit for gitlab', () => {
    const submitSpy = jest.spyOn(findSubmit(), 'click');
    findImportGitlabButton().click();

    expect(findImportUrlValue()).toBe('/import/gitlab_project');
    expect(submitSpy).toHaveBeenCalled();
  });
});
