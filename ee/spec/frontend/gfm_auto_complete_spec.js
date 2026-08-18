import $ from 'jquery';
import GfmAutoCompleteEE, {
  Q_ISSUE_SUB_COMMANDS,
  Q_MERGE_REQUEST_SUB_COMMANDS,
} from 'ee/gfm_auto_complete';
import { TEST_HOST } from 'helpers/test_constants';
import GfmAutoComplete from '~/gfm_auto_complete';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import waitForPromises from 'helpers/wait_for_promises';
import { mockIterations, mockEpics } from 'ee_jest/gfm_auto_complete/mock_data';
import { ISSUABLE_EPIC } from '~/work_items/constants';
import { availableStatuses } from '~/graphql_shared/issuable_client_state';
import AjaxCache from '~/lib/utils/ajax_cache';

jest.mock('~/graphql_shared/issuable_client_state', () => ({
  availableStatuses: jest.fn().mockReturnValue({
    'gitlab-org/gitlab-test': {
      'gid://gitlab/WorkItems::Type/1': [
        {
          __typename: 'WorkItemStatus',
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/1',
          name: 'To do',
          description: null,
          iconName: 'status-waiting',
          color: '#737278',
          position: 0,
        },
        {
          __typename: 'WorkItemStatus',
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/2',
          name: 'In progress',
          description: null,
          iconName: 'status-running',
          color: '#1f75cb',
          position: 0,
        },
        {
          __typename: 'WorkItemStatus',
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/3',
          name: 'Done',
          description: null,
          iconName: 'status-success',
          color: '#108548',
          position: 0,
        },
        {
          __typename: 'WorkItemStatus',
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/4',
          name: "Won't do",
          description: null,
          iconName: 'status-cancelled',
          color: '#DD2B0E',
          position: 0,
        },
      ],
    },
  }),
}));

const mockSpriteIcons = '/icons.svg';

describe('GfmAutoCompleteEE', () => {
  const dataSources = {
    epics: `${TEST_HOST}/autocomplete_sources/epics`,
    labels: `${TEST_HOST}/autocomplete_sources/labels`,
    iterations: `${TEST_HOST}/autocomplete_sources/iterations`,
  };

  let autocomplete;
  let $textarea;

  const triggerDropdown = (textarea, text) => {
    textarea
      .trigger('focus')
      .val($textarea.val() + text)
      .caret('pos', -1);
    textarea.trigger('keyup');

    jest.runOnlyPendingTimers();
  };

  const getDropdownItems = (id) => {
    const dropdown = document.getElementById(id);

    return Array.from(dropdown?.getElementsByTagName('li') || []);
  };

  const getDropdownSubcommands = (id) =>
    getDropdownItems(id).map((x) => ({
      name: x.querySelector('.name').textContent,
      description: x.querySelector('.description').textContent,
    }));

  beforeEach(() => {
    window.gon = { sprite_icons: mockSpriteIcons };
  });

  afterEach(() => {
    resetHTMLFixture();

    $textarea = null;

    autocomplete?.destroy();
    autocomplete = null;
  });

  it('should have enableMap', () => {
    autocomplete = new GfmAutoCompleteEE(dataSources);
    autocomplete.setup($('<input type="text" />'));

    expect(autocomplete.enableMap).not.toBeNull();
  });

  describe('Issues.templateFunction', () => {
    it('should return html with id and title', () => {
      expect(GfmAutoComplete.Issues.templateFunction({ id: 42, title: 'Sample Epic' })).toBe(
        '<li><small>42</small> Sample Epic</li>',
      );
    });

    it('should replace id with reference if reference is set', () => {
      expect(
        GfmAutoComplete.Issues.templateFunction({
          id: 42,
          title: 'Another Epic',
          reference: 'foo&42',
        }),
      ).toBe('<li><small>foo&amp;42</small> Another Epic</li>');
    });

    it('should include the epic svg image when iconName is provided', () => {
      const expectedHtml = `<li><svg class="gl-fill-icon-subtle s16 gl-mr-2"><use xlink:href="/icons.svg#work-item-epic" /></svg><small>5</small> Some Work Item Epic</li>`;
      expect(
        GfmAutoComplete.Issues.templateFunction({
          id: 5,
          title: 'Some Work Item Epic',
          iconName: ISSUABLE_EPIC,
        }),
      ).toBe(expectedHtml);
    });
  });

  describe('Epics', () => {
    const { id, title } = mockEpics[0];
    const expectedDropdownItems = [`&${id} ${title}`];

    beforeEach(() => {
      setHTMLFixture('<textarea></textarea>');
      $textarea = $('textarea');
      autocomplete = new GfmAutoCompleteEE(dataSources);
      autocomplete.setup($textarea, { epics: true, epicsAlternative: true });
      autocomplete.cachedData['&'] = [...mockEpics];
      autocomplete.cachedData['[epic:'] = [...mockEpics];
    });

    it('& shows epics', () => {
      triggerDropdown($textarea, '&');
      const epics = getDropdownItems('at-view-epics');
      expect(epics).toHaveLength(mockEpics.length);
      expect(epics.map((x) => x.textContent.trim())).toEqual(expectedDropdownItems);
    });

    it('[epic: shows epics', () => {
      triggerDropdown($textarea, '[epic:');
      const epics = getDropdownItems('at-view-epicsalternative');
      expect(epics).toHaveLength(mockEpics.length);
      expect(epics.map((x) => x.textContent.trim())).toEqual(expectedDropdownItems);
    });
  });

  describe('Iterations', () => {
    beforeEach(() => {
      setHTMLFixture('<textarea></textarea>');
      $textarea = $('textarea');
      autocomplete = new GfmAutoCompleteEE(dataSources);
      autocomplete.setup($textarea, { iterations: true });
    });

    it("should list iterations when '/iteration *iteration:' is typed", () => {
      autocomplete.cachedData['*iteration:'] = [...mockIterations];

      const { id, title } = mockIterations[0];
      const expectedDropdownItems = [`*iteration:${id} ${title}`];

      triggerDropdown($textarea, '/iteration *iteration:');

      expect(getDropdownItems('at-view-iterations').map((x) => x.textContent.trim())).toEqual(
        expectedDropdownItems,
      );
    });

    describe('templateFunction', () => {
      const { templateFunction } = GfmAutoCompleteEE.Iterations;

      it('should return html with id and title', () => {
        expect(templateFunction({ id: 42, title: 'Foobar Iteration' })).toBe(
          '<li><small>*iteration:42</small> Foobar Iteration</li>',
        );
      });

      it.each`
        xssPayload                                           | escapedPayload
        ${'<script>alert(1)</script>'}                       | ${'&lt;script&gt;alert(1)&lt;/script&gt;'}
        ${'%3Cscript%3E alert(1) %3C%2Fscript%3E'}           | ${'&lt;script&gt; alert(1) &lt;/script&gt;'}
        ${'%253Cscript%253E alert(1) %253C%252Fscript%253E'} | ${'&lt;script&gt; alert(1) &lt;/script&gt;'}
      `('escapes title correctly', ({ xssPayload, escapedPayload }) => {
        expect(templateFunction({ id: 42, title: xssPayload })).toBe(
          `<li><small>*iteration:42</small> ${escapedPayload}</li>`,
        );
      });
    });
  });

  describe('AmazonQ quick action', () => {
    const EXPECTATION_ISSUE_SUB_COMMANDS = [
      {
        name: 'dev',
        description: Q_ISSUE_SUB_COMMANDS.dev.description,
      },
      {
        name: 'transform',
        description: Q_ISSUE_SUB_COMMANDS.transform.description,
      },
    ];
    const EXPECTATION_MR_SUB_COMMANDS = [
      {
        name: 'dev',
        description: Q_MERGE_REQUEST_SUB_COMMANDS.dev.description,
      },
      {
        name: 'review',
        description: Q_MERGE_REQUEST_SUB_COMMANDS.review.description,
      },
    ];
    const EXPECTATION_MR_DIFF_SUB_COMMANDS = [...EXPECTATION_MR_SUB_COMMANDS];

    describe.each`
      availableCommand | textareaAttributes                                             | expectation
      ${'foo'}         | ${''}                                                          | ${[]}
      ${'q'}           | ${''}                                                          | ${EXPECTATION_ISSUE_SUB_COMMANDS}
      ${'q'}           | ${'data-noteable-type="MergeRequest"'}                         | ${EXPECTATION_MR_SUB_COMMANDS}
      ${'q'}           | ${'data-noteable-type="MergeRequest" data-can-suggest="true"'} | ${EXPECTATION_MR_DIFF_SUB_COMMANDS}
    `(
      'with availableCommands=$availableCommand, textareaAttributes=$textareaAttributes',
      ({ availableCommand, textareaAttributes, expectation }) => {
        beforeEach(() => {
          jest
            .spyOn(AjaxCache, 'retrieve')
            .mockReturnValue(Promise.resolve([{ name: availableCommand }]));
          setHTMLFixture(
            `<textarea data-supports-quick-actions="true" ${textareaAttributes}></textarea>`,
          );
          autocomplete = new GfmAutoCompleteEE({
            commands: `${TEST_HOST}/autocomplete_sources/commands`,
          });
          $textarea = $('textarea');
          autocomplete.setup($textarea, {});
        });

        it('renders expected sub commands', async () => {
          triggerDropdown($textarea, '/');

          await waitForPromises();

          triggerDropdown($textarea, 'q ');

          expect(getDropdownSubcommands('at-view-q')).toEqual(expectation);
        });
      },
    );
  });

  describe('Statuses', () => {
    const mockWorkItemFullPath = 'gitlab-org/gitlab-test';
    const mockWorkItemTypeId = 'gid://gitlab/WorkItems::Type/1';

    beforeEach(() => {
      document.body.dataset.page = 'projects:issues:show';
      setHTMLFixture(`
        <section>
          <div class="js-gfm-wrapper"
            data-work-item-full-path="${mockWorkItemFullPath}"
            data-work-item-type-id="${mockWorkItemTypeId}">
            <textarea></textarea>
          </div>
        </section>
      `);
      $textarea = $('textarea');
      autocomplete = new GfmAutoCompleteEE(dataSources);
      autocomplete.setup($textarea, { statuses: true });
    });

    it('should list all statuses when `/status "` is typed', () => {
      const expectedDropdownItems = ['To do', 'In progress', 'Done', "Won't do"];

      triggerDropdown($textarea, '/status "');

      expect(availableStatuses).toHaveBeenCalled();
      expect(
        getDropdownItems('at-view-quotedCompletions').map((x) => x.textContent.trim()),
      ).toEqual(expectedDropdownItems);
    });

    it('should list only matching statuses when `/status "do` is typed', () => {
      const expectedDropdownItems = ['To do', "Won't do", 'Done'];

      triggerDropdown($textarea, '/status "do');

      expect(availableStatuses).toHaveBeenCalled();
      expect(
        getDropdownItems('at-view-quotedCompletions').map((x) => x.textContent.trim()),
      ).toEqual(expectedDropdownItems);
    });

    describe('templateFunction', () => {
      const { templateFunction } = GfmAutoCompleteEE.Statuses;
      const mockStatus = {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/1',
        name: 'To do',
        iconName: 'status-waiting',
        color: '#737278',
      };

      it('should return html with status icon and name', () => {
        expect(templateFunction({ ...mockStatus })).toMatchInlineSnapshot(`
          <li
            data-id="gid://gitlab/WorkItems::Statuses::Custom::Status/1"
          >
            <svg
              class="gl-fill-current gl-mr-2 s12"
              style="color: #737278;"
            >
              <use
                xlink:href="/icons.svg#status-waiting"
              />
            </svg>
            <span>
              To do
            </span>
          </li>
        `);
      });

      it.each`
        xssPayload                                           | escapedPayload
        ${'<script>alert(1)</script>'}                       | ${'&lt;script&gt;alert(1)&lt;/script&gt;'}
        ${'%3Cscript%3E alert(1) %3C%2Fscript%3E'}           | ${'&lt;script&gt; alert(1) &lt;/script&gt;'}
        ${'%253Cscript%253E alert(1) %253C%252Fscript%253E'} | ${'&lt;script&gt; alert(1) &lt;/script&gt;'}
      `('escapes name correctly for "$xssPayload"', ({ xssPayload, escapedPayload }) => {
        // eslint-disable-next-line jest/no-interpolation-in-snapshots
        expect(templateFunction({ ...mockStatus, name: xssPayload })).toMatchInlineSnapshot(`
          <li
            data-id="gid://gitlab/WorkItems::Statuses::Custom::Status/1"
          >
            <svg
              class="gl-fill-current gl-mr-2 s12"
              style="color: #737278;"
            >
              <use
                xlink:href="/icons.svg#status-waiting"
              />
            </svg>
            <span>
              ${escapedPayload}
            </span>
          </li>
        `);
      });
    });
  });
});
