# redmics - redmine ics export plugin
# Copyright (c) 2011-2012  Frank Schwarz, frank.schwarz@buschmais.com
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

module ApplicationControllerFindCurrentUserICS
  def self.included(base)
    base.class_eval {
      include InstanceMethods
      alias_method_chain :find_current_user, :ics
    }
  end

  module InstanceMethods
    # enable rss key auth also for ics format
    def find_current_user_with_ics
      result = find_current_user_without_ics
      return result if result
      if params[:format] == 'ics' && params[:key] && request.get? && accept_rss_auth?
        User.find_by_rss_key(params[:key])
      end
    end
  end
end

module SettingsControllerPluginDefaults
  def self.included(base)
    base.class_eval {
      include InstanceMethods
      alias_method_chain :plugin, :defaults
    }
  end

  module InstanceMethods
    # add default settings if missing
    def plugin_with_defaults
      result = plugin_without_defaults
      # filter for our own plugin
      return result unless @plugin
      return result unless @plugin.id == :redmine_ics_export
      return result unless @settings
      # add all missing defaults
      @plugin.settings[:default].each { |key, value|
        @settings[key] = value unless @settings[key]
      }
      return result
    end
  end
end

SettingsController.send(:include, SettingsControllerPluginDefaults)
ApplicationController.send(:include, ApplicationControllerFindCurrentUserICS)
