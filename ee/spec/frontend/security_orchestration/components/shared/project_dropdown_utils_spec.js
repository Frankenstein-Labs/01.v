import {
  PROJECT_DROPDOWN_I18N,
  createDebouncedSearch,
  normalizeSearchTerm,
  projectsToListboxItems,
  getDropdownCategory,
  getDropdownVariant,
  getProjectsText,
  filterExistingSelectedIds,
} from 'ee/security_orchestration/components/shared/project_dropdown_utils';

describe('project_dropdown_utils', () => {
  describe('PROJECT_DROPDOWN_I18N', () => {
    it('has the correct header text', () => {
      expect(PROJECT_DROPDOWN_I18N.projectDropdownHeader).toBe('Select projects');
    });
  });

  describe('createDebouncedSearch', () => {
    it('creates a debounced function', () => {
      const mockFn = jest.fn();
      const debouncedFn = createDebouncedSearch(mockFn);

      expect(typeof debouncedFn).toBe('function');
      expect(typeof debouncedFn.cancel).toBe('function');
    });
  });

  describe('normalizeSearchTerm', () => {
    it('trims whitespace', () => {
      expect(normalizeSearchTerm('  test  ')).toBe('test');
    });

    it('handles empty string', () => {
      expect(normalizeSearchTerm('')).toBe('');
    });

    it('handles undefined', () => {
      expect(normalizeSearchTerm()).toBe('');
    });
  });

  describe('projectsToListboxItems', () => {
    const mockProjects = [
      { id: '1', name: 'Project 1', fullPath: 'group/project-1' },
      { id: '2', name: 'Project 2', fullPath: 'group/project-2' },
    ];

    it('transforms projects to listbox items', () => {
      const result = projectsToListboxItems(mockProjects);

      expect(result).toEqual([
        { value: '1', text: 'Project 1', fullPath: 'group/project-1' },
        { value: '2', text: 'Project 2', fullPath: 'group/project-2' },
      ]);
    });

    it('filters items by search term in name', () => {
      const result = projectsToListboxItems(mockProjects, 'Project 1');

      expect(result).toHaveLength(1);
      expect(result[0].value).toBe('1');
    });

    it('filters items by search term in fullPath', () => {
      const result = projectsToListboxItems(mockProjects, 'project-2');

      expect(result).toHaveLength(1);
      expect(result[0].value).toBe('2');
    });
  });

  describe('getDropdownCategory', () => {
    it('returns primary when state is true', () => {
      expect(getDropdownCategory(true)).toBe('primary');
    });

    it('returns secondary when state is false', () => {
      expect(getDropdownCategory(false)).toBe('secondary');
    });
  });

  describe('getDropdownVariant', () => {
    it('returns default when state is true', () => {
      expect(getDropdownVariant(true)).toBe('default');
    });

    it('returns danger when state is false', () => {
      expect(getDropdownVariant(false)).toBe('danger');
    });
  });

  describe('getProjectsText', () => {
    it('returns singular form for 1', () => {
      expect(getProjectsText(1)).toBe('project');
    });

    it('returns plural form for multiple', () => {
      expect(getProjectsText(5)).toBe('projects');
    });

    it('returns plural form for 0', () => {
      expect(getProjectsText(0)).toBe('projects');
    });
  });

  describe('filterExistingSelectedIds', () => {
    const projectIds = ['1', '2', '3'];

    it('filters to only include existing ids', () => {
      const selectedIds = ['1', '4', '2'];

      expect(filterExistingSelectedIds(selectedIds, projectIds)).toEqual(['1', '2']);
    });

    it('returns empty array when no matches', () => {
      const selectedIds = ['4', '5'];

      expect(filterExistingSelectedIds(selectedIds, projectIds)).toEqual([]);
    });

    it('returns all when all match', () => {
      const selectedIds = ['1', '2'];

      expect(filterExistingSelectedIds(selectedIds, projectIds)).toEqual(['1', '2']);
    });
  });
});
