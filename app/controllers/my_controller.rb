# redmics - redmine ics export plugin
# Copyright (c) 2011  Frank Schwarz, frank.schwarz@buschmais.com
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

class MyController < ApplicationController
  unloadable
  
  def redmics_settings
    @user = User.current
    global_prefs = Setting.plugin_redmine_ics_export
    if request.post?
      [:redmics_icsrender_issues, :redmics_icsrender_versions].each { |item| 
        @user.pref[item] = params[:settings][item]
      }
      if @user.save
        @user.pref.save
        flash.now[:notice] = l(:notice_redmics_userprefs_updated)
      end
    end
    @settings = { }
    [:redmics_icsrender_issues, :redmics_icsrender_versions].each { |item|  
      @settings[item] = @user.pref[item] || global_prefs[item]
    }
  end
end
