# redmics - redmine ics export plugin
# Copyright (c) 2012 Frank Schwarz, frank.schwarz@buschmais.com
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

ActionController::Routing::Routes.draw do |map|
  map.connect 'icalendar/all_projects/:assignment/issues.:format', :controller => 'i_calendar', :action => 'index'
  map.connect 'icalendar/all_projects/:assignment/:status/issues.:format', :controller => 'i_calendar', :action => 'index'
  map.connect 'icalendar/:project_id/:assignment/issues.:format', :controller => 'i_calendar', :action => 'index'
  map.connect 'icalendar/:project_id/:assignment/:status/issues.:format', :controller => 'i_calendar', :action => 'index'
  map.connect 'my/redmics_settings', :controller => 'my', :action => 'redmics_settings'
  map.connect 'my/redmics_settings/reset', :controller => 'my', :action => 'redmics_settings_reset'
end
