import { PageContextProvider } from 'ee/ai/duo_agentic_chat/context/page_context_provider';
import {
  DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
  AI_CONTEXT_ID_PAGE_CONTEXT,
} from 'ee/ai/constants';

describe('PageContextProvider', () => {
  let provider;

  beforeEach(() => {
    delete window.location;
    window.location = {
      href: 'http://test.com/test/path',
      pathname: '/test/path',
    };
    Object.defineProperty(document, 'title', {
      value: 'Test Page Title',
      configurable: true,
    });
    provider = new PageContextProvider({ projectPath: 'group/project' });
  });

  it('returns empty array when page has not changed', async () => {
    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { pageChanged: false },
    };

    const result = await provider.getItems(contextInjectionState);

    expect(result).toEqual([]);
  });

  it('returns page context with correct structure', async () => {
    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { pageChanged: true },
    };

    const result = await provider.getItems(contextInjectionState);

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(AI_CONTEXT_ID_PAGE_CONTEXT);
    expect(result[0].content).toContain('http://test.com/test/path');
    expect(result[0].content).toContain('Test Page Title');
    expect(result[0].category).toBe(DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY);
  });

  it('marks provider as provided after first call', async () => {
    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { pageChanged: true },
    };

    await provider.getItems(contextInjectionState);

    expect(contextInjectionState.PageContextProvider.hasAlreadyProvided).toBe(true);
  });

  it('returns empty array when already provided', async () => {
    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { pageChanged: true },
      PageContextProvider: { hasAlreadyProvided: true },
    };

    const result = await provider.getItems(contextInjectionState);

    expect(result).toEqual([]);
  });

  it('includes correct metadata', async () => {
    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { pageChanged: true },
    };

    const result = await provider.getItems(contextInjectionState);
    const metadata = JSON.parse(result[0].metadata);

    expect(metadata.enabled).toBe(true);
    expect(metadata.icon).toBe('link');
    expect(metadata.subType).toBe('open_tab');
    expect(metadata.projectPath).toBe('group/project');
    expect(metadata.pagePath).toBe('/test/path');
  });

  it('handles missing window/document gracefully', async () => {
    const originalWindow = global.window;
    delete global.window;

    provider = new PageContextProvider({ projectPath: 'group/project' });
    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { pageChanged: true },
    };

    const result = await provider.getItems(contextInjectionState);

    expect(result[0].content).toContain('<current_gitlab_page_url></current_gitlab_page_url>');

    global.window = originalWindow;
  });

  it('handles null contextInjectionState', async () => {
    const result = await provider.getItems(null);

    expect(result).toEqual([]);
  });
});
