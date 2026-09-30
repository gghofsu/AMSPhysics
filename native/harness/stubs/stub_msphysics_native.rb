# Fakes for the native (C extension) classes of MSPhysics, to be used together
# with stub_sketchup_api.rb in the development harness.
#
# The natives are only faked on the surface: the harness is able to check that
# the Ruby part of the extension loads and wires itself up, not that the
# simulation runs.
module StubNative
  BODY_STATES = [:sleeping, :active].freeze

  def self.next_address
    @address ||= 0
    @address += 16
  end
end

class StubUIObject
  include StubAttributes
  attr_accessor :valid, :destroyed
  def initialize(*args)
    @attributes = {}
    @valid = true
    @destroyed = false
    @address = StubNative.next_address
  end
  def valid?; !@destroyed; end
  def destroyed?; @destroyed; end
  def address; @address; end
  def to_i; @address; end
  def set_validation_proc(*args, &block); true; end
end

module MSPhysics
  module Newton
    VERSION = '4.00.00'.freeze

    def self.get_version; VERSION; end
    def self.get_float_size; 8; end
    def self.get_memory_used; 0; end
    def self.enable_object_validation(state); state; end
    def self.get_all_worlds; []; end
    def self.get_all_bodies; []; end
    def self.get_all_joints; []; end
    def self.get_all_gears; []; end
    def self.get_all_materials; []; end
    def self.get_all_collisions; []; end
    def self.get_all_contact_materials; []; end
    def self.set_solver_model(value); value; end
    def self.get_global_solver_iterations; 0; end
    def self.set_global_solver_iterations(value); value; end
    def self.clean_up_unused_materials; true; end
    def self.remove_all_materials; true; end
    def self.remove_all_collisions; true; end

    class World < StubUIObject
      def initialize(*args); super; end
      def destroy; @destroyed = true; true; end
      def update(timestep); true; end
      def add_body(*args); MSPhysics::Newton::Body.new; end
      def add_joint(*args); MSPhysics::Newton::Joint.new; end
      def add_gear(*args); MSPhysics::Newton::Gear.new; end
      def add_material(*args); MSPhysics::Newton::Material.new; end
      def add_collision(*args); MSPhysics::Newton::Collision.new; end
      def add_contact_material(*args); MSPhysics::Newton::ContactMaterial.new; end
      def get_version; VERSION; end
      def get_gravity; [0.0, 0.0, -9.81]; end
      def set_gravity(*args); true; end
      def set_solver_model(*args); true; end
      def get_solver_model; 0; end
      def set_update_timestep(*args); true; end
      def set_solver_iterations(*args); true; end
      def set_scale(*args); true; end
      def get_scale; [1.0, 1.0, 1.0]; end
      def ray_cast(*args); nil; end
      def collide(*args); false; end
      def convex_cast(*args); false; end
      def continuous_collision_check(*args); false; end
      def get_info; {}; end
      def get_proxy_address; @address; end
    end

    class Joint < StubUIObject; end
    class Gear < StubUIObject; end
    class Material < StubUIObject; end
    class Collision < StubUIObject; end
    class ContactMaterial < StubUIObject; end
    class Body < StubUIObject; end
  end
end

module MSPhysics
  module SDL
    INIT_TIMER    = 0x00000001
    INIT_AUDIO    = 0x00000010
    INIT_VIDEO    = 0x00000020
    INIT_JOYSTICK = 0x00000200
    INIT_EVENTS   = 0x00004000
    INIT_EVERYTHING = INIT_TIMER | INIT_AUDIO | INIT_VIDEO | INIT_JOYSTICK | INIT_EVENTS

    def self.init(*args); true; end
    def self.init_sub_system(*args); true; end
    def self.quit_sub_system(*args); true; end
    def self.quit; true; end
    def self.get_error; ''; end
    def self.get_joystick_axis(*args); 0; end
  end

  module Mixer
    INIT_MP3 = 0x00000001
    INIT_MOD = 0x00000002
    INIT_FLAC = 0x00000008
    INIT_MODPLUG = 0x00000010
    INIT_SUPPORTED = INIT_MP3 | INIT_MOD | INIT_FLAC | INIT_MODPLUG
    DEFAULT_FORMAT = 0x8010 # AUDIO_S16LSB

    def self.init(*args); true; end
    def self.quit(*args); true; end
    def self.open_audio(*args); true; end
    def self.close_audio; true; end
    def self.allocate_channels(count = 8); count; end
    def self.get_error; ''; end
  end

  class Sound < StubUIObject
    def self.create_from_dir(*args); []; end
    def self.create_from_buffer(*args); new; end
    def self.destroy_all; true; end
    def self.get_by_name(*args); nil; end
    def self.update_effects; true; end
    def initialize(*args); super; end
    def play(*args); true; end
    def stop(*args); true; end
    def pause; true; end
    def resume; true; end
    def destroy; @destroyed = true; true; end
    def set_name(name); @name = name; end
    def get_name; @name; end
    def set_position_3d(*args); true; end
  end

  class Music < Sound
    def self.create_from_dir(*args); []; end
    def self.create_from_buffer(*args); new; end
    def self.destroy_all; true; end
    def self.get_by_name(*args); nil; end
    def self.is_paused?(*args); false; end
    def pause(*args); true; end
    def resume(*args); true; end
    def stop(*args); true; end
    def play(*args); true; end
  end
end
