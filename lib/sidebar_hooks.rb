# redmics - redmine ics export plugin
# Copyright (c) 2010-2012 Frank Schwarz, frank.schwarz@buschmais.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class SidebarHooks < Redmine::Hook::ViewListener
  
  def view_issues_sidebar_planning_bottom(context = { })
    project = context[:project]
    user = User.current
    
    return '' unless user.allowed_to?(:view_calendar, project, :global => true)
    
    result = "<h3>%s</h3>\n" % l(:label_icalendar_header)
    
    label = {
      :my  => l(:label_issues_mine),
      :assigned => l(:label_issues_assigned),
      :all => l(:label_issues_all)
    }
    label.delete(:my) if user.anonymous?
    label_open = l(:label_issues_open_only)
    label.keys.sort_by {|sym| sym.to_s}.each {|type|
      link_all  = link_to(label[type], 
        {
          :controller => 'i_calendar',
          :assignment => type,
          :action => 'index', 
          :project_id => project, 
          :key => User.current.rss_key, 
          :format => 'ics'
        },
        :title => l(:toolip_icalendar_link))
      link_open = link_to(label_open,
        {
          :controller => 'i_calendar',
          :assignment => type,
          :status => 'open', 
          :action => 'index', 
          :project_id => project, 
          :key => User.current.rss_key, 
          :format => 'ics'
        },
        :title => l(:toolip_icalendar_link))
      result += "#{link_all} (#{link_open})<br/>\n";
    }
    return result
  end

end
