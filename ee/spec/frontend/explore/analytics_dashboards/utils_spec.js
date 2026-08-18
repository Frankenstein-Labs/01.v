import {
  wrapGlqlInVisualization,
  wrapVisualizationInPanel,
  parseGlqlTitle,
  serializePanelsForMutation,
} from 'ee/explore/analytics_dashboards/utils';

describe('EE Analytics Dashboards utils', () => {
  describe('wrapGlqlInVisualization', () => {
    it('wraps a GLQL query in a Glql visualization config', () => {
      const glql = 'assignee = currentUser()';

      expect(wrapGlqlInVisualization(glql)).toEqual({
        type: 'Glql',
        options: {},
        data: {
          type: 'glql',
          query: {
            glql,
          },
        },
      });
    });
  });

  describe('parseGlqlTitle', () => {
    it('returns the title defined in the GLQL frontmatter', () => {
      const glql = ['---', 'title: My open issues', '---', 'assignee = currentUser()'].join('\n');

      expect(parseGlqlTitle(glql)).toBe('My open issues');
    });

    it('returns "Untitled" when the query has no frontmatter title', () => {
      expect(parseGlqlTitle('assignee = currentUser()')).toBe('Untitled');
    });

    it('returns "Untitled" when the frontmatter defines other fields but no title', () => {
      const glql = ['---', 'display: table', '---', 'assignee = currentUser()'].join('\n');

      expect(parseGlqlTitle(glql)).toBe('Untitled');
    });

    it('returns "Untitled" when the frontmatter is malformed rather than throwing', () => {
      const glql = ['---', 'title: [unclosed bracket', '---', 'type = Issue'].join('\n');

      expect(() => parseGlqlTitle(glql)).not.toThrow();
      expect(parseGlqlTitle(glql)).toBe('Untitled');
    });
  });

  describe('wrapVisualizationInPanel', () => {
    const visualization = { type: 'Glql', options: {} };

    it('wraps a visualization in a panel with default grid attributes', () => {
      expect(wrapVisualizationInPanel(visualization)).toMatchObject({
        visualization,
        gridAttributes: {
          width: 6,
          height: 3,
        },
      });
    });

    it('sets the panel title from the given title', () => {
      expect(wrapVisualizationInPanel(visualization, 'My panel').title).toBe('My panel');
    });

    it('assigns a unique panel id', () => {
      const panelOne = wrapVisualizationInPanel(visualization);
      const panelTwo = wrapVisualizationInPanel(visualization);

      expect(panelOne.id).toMatch(/^panel-\d+$/);
      expect(panelTwo.id).toMatch(/^panel-\d+$/);
      expect(panelOne.id).not.toBe(panelTwo.id);
    });
  });

  describe('serializePanelsForMutation', () => {
    const visualization = { type: 'Glql', options: {} };

    it('returns an empty array when there are no panels', () => {
      expect(serializePanelsForMutation()).toEqual([]);
      expect(serializePanelsForMutation([])).toEqual([]);
    });

    it('maps the visualization to visualizationConfig and drops the client-side id', () => {
      const panels = [
        {
          id: 'panel-1',
          title: 'Open issues',
          visualization,
          gridAttributes: { xPos: 0, yPos: 0, width: 3, height: 1 },
        },
      ];

      expect(serializePanelsForMutation(panels)).toEqual([
        {
          title: 'Open issues',
          visualizationConfig: visualization,
          gridAttributes: { xPos: 0, yPos: 0, width: 3, height: 1 },
        },
      ]);
    });

    it('preserves any remaining panel fields', () => {
      const panels = [
        {
          id: 'panel-1',
          title: 'My merge requests',
          options: { foo: 'bar' },
          visualization,
          gridAttributes: { width: 6, height: 3 },
        },
      ];

      expect(serializePanelsForMutation(panels)).toEqual([
        {
          title: 'My merge requests',
          options: { foo: 'bar' },
          visualizationConfig: visualization,
          gridAttributes: { width: 6, height: 3 },
        },
      ]);
    });

    it('serializes every panel', () => {
      const panels = [
        { id: 'panel-1', title: 'One', visualization },
        { id: 'panel-2', title: 'Two', visualization },
      ];

      expect(serializePanelsForMutation(panels)).toEqual([
        { title: 'One', visualizationConfig: visualization },
        { title: 'Two', visualizationConfig: visualization },
      ]);
    });
  });
});
