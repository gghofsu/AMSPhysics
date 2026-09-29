# Harness test: exercise the pure Ruby fallback implementation of AMS Library
# (ams_lib/ruby_fallback.rb), which is loaded when there is no native build of
# the library for the Ruby version used by the running SketchUp.
#
# The calls below mirror the AMS Library API that MSPhysics uses.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_ams_fallback.rb
$stdout.sync = true

require 'sketchup.rb'
require 'ams_lib.rb'
require 'ams_lib/main'

failures = []
$checks = 0

def check(failures, label)
  result = yield
  $checks += 1
  puts format('  ok   %-52s => %s', label, result.inspect[0, 60])
  result
rescue Exception => err
  failures << "#{label}: #{err.class}: #{err.message}"
  puts format('  FAIL %-52s !! %s: %s', label, err.class, err.message)
  nil
end

def check_raises(failures, label, exception)
  yield
  failures << "#{label}: no #{exception} raised"
  puts format('  FAIL %-52s !! no %s raised', label, exception)
rescue exception
  $checks += 1
  puts format('  ok   %-52s => raised %s', label, exception)
rescue Exception => err
  failures << "#{label}: #{err.class}: #{err.message}"
  puts format('  FAIL %-52s !! %s: %s', label, err.class, err.message)
end

# Fakes for the SketchUp object model, to exercise the group geometry helpers.
class FakeVertex < ::Sketchup::Vertex
  attr_reader :position
  def initialize(point); @position = point; end
end

class FakeFace < ::Sketchup::Face
  attr_reader :points
  def initialize(points); @points = points; end
  def vertices; @points.map { |point| FakeVertex.new(point) }; end
  def outer_loop; self; end
  def mesh(flags)
    mesh = ::Geom::PolygonMesh.new(0, 0, 0)
    mesh.add_polygon(*@points)
    mesh
  end
  def transformation; ::Geom::Transformation.new; end
end

class FakeDefinition < ::Sketchup::ComponentDefinition
  attr_reader :entities
  def initialize(items)
    @entities = MockCollection.new
    items.each { |item| @entities.add(item) }
  end
end

class FakeGroup < ::Sketchup::Group
  attr_reader :definition
  def initialize(items, transformation = nil)
    @definition = FakeDefinition.new(items)
    @transformation = transformation || ::Geom::Transformation.new
  end
  def transformation; @transformation; end
end

QUAD = [
  Geom::Point3d.new(0, 0, 0),
  Geom::Point3d.new(1, 0, 0),
  Geom::Point3d.new(1, 1, 0),
  Geom::Point3d.new(0, 1, 0),
].freeze

plain_group = FakeGroup.new([FakeFace.new(QUAD)])
nested_group = FakeGroup.new([FakeGroup.new([FakeFace.new(QUAD)], Geom::Transformation.translation(10, 0, 0))])

puts "== AMS Library #{AMS::Lib::VERSION} / Ruby #{RUBY_VERSION} =="
puts "   NATIVE_EXTENSION_LOADED=#{AMS::NATIVE_EXTENSION_LOADED} RUBY_FALLBACK_LOADED=#{AMS::RUBY_FALLBACK_LOADED}"

puts '== AMS (helper functions) =='
check(failures, 'AMS.clamp(5, 0, 10)') { AMS.clamp(5, 0, 10) }
check(failures, 'AMS.clamp(-5, 0, 10)') { AMS.clamp(-5, 0, 10) }
check(failures, 'AMS.clamp(15, 0, 10)') { AMS.clamp(15, 0, 10) }
check(failures, 'AMS.min(3, 7)') { AMS.min(3, 7) }
check(failures, 'AMS.max(3, 7)') { AMS.max(3, 7) }
check(failures, 'AMS.sign(-4)') { AMS.sign(-4) }
check(failures, 'AMS.get_temp_dir') { AMS.get_temp_dir }
check(failures, 'AMS.get_folder_path(0)') { AMS.get_folder_path(0) }
check(failures, 'AMS.refresh_toolbars') { AMS.refresh_toolbars }

puts '== AMS.validate_type =='
check(failures, 'AMS.validate_type(1, Numeric)') { AMS.validate_type(1, Numeric) }
check_raises(failures, 'AMS.validate_type(nil, Numeric)', TypeError) { AMS.validate_type(nil, Numeric) }
check_raises(failures, 'AMS.validate_type -> custom error only', TypeError) {
  AMS.validate_type(nil, Numeric) { raise TypeError, 'expected' }
}

puts '== AMS::DLL =='
check(failures, 'AMS::DLL.load_library') { AMS::DLL.load_library('kernel32') }
check(failures, 'AMS::DLL.get_module_handle') { AMS::DLL.get_module_handle('kernel32') }
check(failures, 'AMS::DLL.free_library') { AMS::DLL.free_library(0) }

puts '== AMS::System =='
check(failures, 'AMS::System.get_windows_version') { AMS::System.get_windows_version }
check(failures, 'AMS::System.is_windows_64bit?') { AMS::System.is_windows_64bit? }
check(failures, 'AMS::System.is_windows_8_or_higher?') { AMS::System.is_windows_8_or_higher? }

puts '== AMS::Keyboard =='
check(failures, "AMS::Keyboard.get_key_code('a')") { AMS::Keyboard.get_key_code('a') }
check(failures, 'AMS::Keyboard.get_key_name(65)') { AMS::Keyboard.get_key_name(65) }
check(failures, "AMS::Keyboard.key_pressed?('a')") { AMS::Keyboard.key_pressed?('a') }
check(failures, "AMS::Keyboard.key_down?('a')") { AMS::Keyboard.key_down?('a') }
check(failures, "AMS::Keyboard.key_up?('a')") { AMS::Keyboard.key_up?('a') }
check(failures, "AMS::Keyboard.key_toggled?('a')") { AMS::Keyboard.key_toggled?('a') }
check(failures, "AMS::Keyboard.key('a')") { AMS::Keyboard.key('a') }
check(failures, "AMS::Keyboard.bind('a')") { AMS::Keyboard.bind('a') }
check(failures, "AMS::Keyboard.unbind('a')") { AMS::Keyboard.unbind('a') }
check(failures, 'AMS::Keyboard.control_down?') { AMS::Keyboard.control_down? }
check(failures, 'AMS::Keyboard.control_up?') { AMS::Keyboard.control_up? }
check(failures, 'AMS::Keyboard.shift_down?') { AMS::Keyboard.shift_down? }
check(failures, 'AMS::Keyboard.shift_up?') { AMS::Keyboard.shift_up? }
check(failures, 'AMS::Keyboard.alt_down?') { AMS::Keyboard.alt_down? }

puts '== AMS::Cursor =='
check(failures, 'AMS::Cursor.is_visible?') { AMS::Cursor.is_visible? }
check(failures, 'AMS::Cursor.show(true)') { AMS::Cursor.show(true) }
check(failures, 'AMS::Cursor.is_visible? after show(true)') { AMS::Cursor.is_visible? }
check(failures, 'AMS::Cursor.show(false)') { AMS::Cursor.show(false) }
check(failures, 'AMS::Cursor.get_pos') { AMS::Cursor.get_pos }
check(failures, 'AMS::Cursor.set_pos(1, 2)') { AMS::Cursor.set_pos(1, 2) }
check(failures, 'AMS::Cursor.clip(0, 0, 100, 100)') { AMS::Cursor.clip(0, 0, 100, 100) }

puts '== AMS::MIDI =='
check(failures, 'AMS::MIDI.is_device_open?') { AMS::MIDI.is_device_open? }
check(failures, 'AMS::MIDI.is_device_open?(0)') { AMS::MIDI.is_device_open?(0) }
check(failures, 'AMS::MIDI.open_device(0)') { AMS::MIDI.open_device(0) }
check(failures, 'AMS::MIDI.play_note(60, 100, 0)') { AMS::MIDI.play_note(60, 100, 0) }
check(failures, 'AMS::MIDI.stop_note(60, 0)') { AMS::MIDI.stop_note(60, 0) }
check(failures, 'AMS::MIDI.change_channel_controller(1, 2, 3)') { AMS::MIDI.change_channel_controller(1, 2, 3) }
check(failures, 'AMS::MIDI.set_note_position(60, 0, 1, 2)') { AMS::MIDI.set_note_position(60, 0, 1, 2) }
check(failures, 'AMS::MIDI.reset') { AMS::MIDI.reset }
check(failures, 'AMS::MIDI.close_device') { AMS::MIDI.close_device }

puts '== AMS::Window =='
check(failures, 'AMS::Window.get_rect(0)') { AMS::Window.get_rect(0) }
check(failures, 'AMS::Window.get_client_rect(0)') { AMS::Window.get_client_rect(0) }
check(failures, 'AMS::Window.get_size(0)') { AMS::Window.get_size(0) }
check(failures, 'AMS::Window.is_active?(0)') { AMS::Window.is_active?(0) }
check(failures, 'AMS::Window.is_maximized?(0)') { AMS::Window.is_maximized?(0) }
check(failures, 'AMS::Window.is_minimized?(0)') { AMS::Window.is_minimized?(0) }
check(failures, 'AMS::Window.is_restored?(0)') { AMS::Window.is_restored?(0) }
check(failures, 'AMS::Window.is_visible?(0)') { AMS::Window.is_visible?(0) }
check(failures, 'AMS::Window.show(0, 1)') { AMS::Window.show(0, 1) }
check(failures, 'AMS::Window.set_rect(0, 0, 0, 100, 100)') { AMS::Window.set_rect(0, 0, 0, 100, 100) }
check(failures, 'AMS::Window.set_pos(0, 10, 10)') { AMS::Window.set_pos(0, 10, 10) }
check(failures, 'AMS::Window.set_size(0, 100, 100)') { AMS::Window.set_size(0, 100, 100) }
check(failures, 'AMS::Window.set_long(0, -16, 1)') { AMS::Window.set_long(0, -16, 1) }
check(failures, 'AMS::Window.get_long(0, -16)') { AMS::Window.get_long(0, -16) }
check(failures, 'AMS::Window.set_layered_attributes(0, 0, 200, 2)') { AMS::Window.set_layered_attributes(0, 0, 200, 2) }
check(failures, 'AMS::Window.set_parent(0, 0)') { AMS::Window.set_parent(0, 0) }
check(failures, 'AMS::Window.bring_to_top(0)') { AMS::Window.bring_to_top(0) }
check(failures, 'AMS::Window.lock_update(0, true)') { AMS::Window.lock_update(0, true) }
check(failures, 'AMS::Window.lock_update(0, false)') { AMS::Window.lock_update(0, false) }
check(failures, 'AMS::Window.close(0)') { AMS::Window.close(0) }

puts '== AMS::Sketchup =='
check(failures, 'AMS::Sketchup.get_main_window') { AMS::Sketchup.get_main_window }
check(failures, 'AMS::Sketchup.is_main_window_active?') { AMS::Sketchup.is_main_window_active? }
check(failures, 'AMS::Sketchup.get_caption') { AMS::Sketchup.get_caption }
check(failures, 'AMS::Sketchup.find_window_by_caption') { AMS::Sketchup.find_window_by_caption('SketchUp') }
check(failures, 'AMS::Sketchup.get_viewport_rect') { AMS::Sketchup.get_viewport_rect }
check(failures, 'AMS::Sketchup.set_viewport_border(1, 1, 1, 1)') { AMS::Sketchup.set_viewport_border(1, 1, 1, 1) }
check(failures, 'AMS::Sketchup.show_toolbars(true)') { AMS::Sketchup.show_toolbars(true) }
check(failures, 'AMS::Sketchup.show_toolbar_container(1, false, false)') { AMS::Sketchup.show_toolbar_container(1, false, false) }
check(failures, 'AMS::Sketchup.show_trays(true)') { AMS::Sketchup.show_trays(true) }
check(failures, 'AMS::Sketchup.show_scenes_bar(true)') { AMS::Sketchup.show_scenes_bar(true) }
check(failures, 'AMS::Sketchup.show_status_bar(true)') { AMS::Sketchup.show_status_bar(true) }
check(failures, 'AMS::Sketchup.show_dialogs(true)') { AMS::Sketchup.show_dialogs(true) }
check(failures, 'AMS::Sketchup.set_menu_bar(true)') { AMS::Sketchup.set_menu_bar(true) }
check(failures, 'AMS::Sketchup.activate_scenes_bar_tab(0)') { AMS::Sketchup.activate_scenes_bar_tab(0) }
check(failures, 'AMS::Sketchup.switch_full_screen(false, 0, 0)') { AMS::Sketchup.switch_full_screen(false, 0, 0) }
check(failures, 'AMS::Sketchup.screen_to_client(0, 1, 2)') { AMS::Sketchup.screen_to_client(0, 1, 2) }
check(failures, 'AMS::Sketchup.client_to_screen(0, 1, 2)') { AMS::Sketchup.client_to_screen(0, 1, 2) }
check(failures, 'AMS::Sketchup.include_dialog(0)') { AMS::Sketchup.include_dialog(0) }
check(failures, 'AMS::Sketchup.ignore_dialog(0)') { AMS::Sketchup.ignore_dialog(0) }
check(failures, 'AMS::Sketchup.refresh') { AMS::Sketchup.refresh }
check(failures, 'AMS::Sketchup.activate') { AMS::Sketchup.activate }
check(failures, 'AMS::Sketchup.deactivate') { AMS::Sketchup.deactivate }
check(failures, 'AMS::Sketchup.messagebox("test")') { AMS::Sketchup.messagebox('test') }
check(failures, 'AMS::Sketchup.threaded_messagebox("test")') { AMS::Sketchup.threaded_messagebox('test') }

puts '== AMS::Geometry (pure math) =='
check(failures, 'AMS::Geometry.transition_number(0, 10, 0.5)') { AMS::Geometry.transition_number(0, 10, 0.5) }
check(failures, 'AMS::Geometry.transition_number(-10, 10, 0.25)') { AMS::Geometry.transition_number(-10, 10, 0.25) }
check(failures, 'AMS::Geometry.transition_color(start, finish, 0.5)') {
  AMS::Geometry.transition_color(Sketchup::Color.new(0, 0, 0), Sketchup::Color.new(255, 255, 255), 0.5).to_a
}
check(failures, 'AMS::Geometry.transition_vector(start, finish, 0.5)') {
  AMS::Geometry.transition_vector(Geom::Vector3d.new(0, 0, 0), Geom::Vector3d.new(2, 4, 6), 0.5).to_a
}
check(failures, 'AMS::Geometry.transition_point(start, finish, 0.5)') {
  AMS::Geometry.transition_point(Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(2, 4, 6), 0.5).to_a
}
check(failures, 'AMS::Geometry.transition_transformation(a, b, 0.5)') {
  AMS::Geometry.transition_transformation(
    Geom::Transformation.new(Geom::Point3d.new(0, 0, 0)),
    Geom::Transformation.new(Geom::Point3d.new(2, 4, 6)),
    0.5
  ).origin.to_a
}
check(failures, 'AMS::Geometry.transition_camera(c1, c2, 0.5)') {
  camera = AMS::Geometry.transition_camera(Sketchup::Camera.new, Sketchup::Camera.new, 0.5)
  camera.eye.to_a
}
check(failures, 'AMS::Geometry.scale_vector(v, 2)') {
  AMS::Geometry.scale_vector(Geom::Vector3d.new(1, 2, 3), 2).to_a
}
check(failures, 'AMS::Geometry.scale_point(p, 2)') {
  AMS::Geometry.scale_point(Geom::Point3d.new(1, 2, 3), 2).to_a
}
check(failures, 'AMS::Geometry.calc_cubic_bezier_point(p0..p3, 0.5)') {
  AMS::Geometry.calc_cubic_bezier_point(
    Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(1, 0, 0),
    Geom::Point3d.new(2, 0, 0), Geom::Point3d.new(3, 0, 0), 0.5
  ).to_a
}
check(failures, 'AMS::Geometry.calc_cubic_bezier_point(p0..p3, 1.0)') {
  AMS::Geometry.calc_cubic_bezier_point(
    Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(1, 0, 0),
    Geom::Point3d.new(2, 0, 0), Geom::Point3d.new(3, 0, 0), 1.0
  ).to_a
}
check(failures, 'AMS::Geometry.calc_cubic_bezier_tangent(p0..p3, 0.5)') {
  AMS::Geometry.calc_cubic_bezier_tangent(
    Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(1, 0, 0),
    Geom::Point3d.new(1, 1, 0), Geom::Point3d.new(2, 1, 0), 0.5
  ).to_a
}
check(failures, 'AMS::Geometry.closest_point_on_line(p, a, b)') {
  AMS::Geometry.closest_point_on_line(Geom::Point3d.new(1, 5, 0), Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(10, 0, 0)).to_a
}
check(failures, 'AMS::Geometry.is_matrix_uniform?(scaling(2))') { AMS::Geometry.is_matrix_uniform?(Geom::Transformation.scaling(2, 2, 2)) }
check(failures, 'AMS::Geometry.is_matrix_uniform?(scaling(1, 2, 3))') { AMS::Geometry.is_matrix_uniform?(Geom::Transformation.scaling(1, 2, 3)) }
check(failures, 'AMS::Geometry.is_matrix_flipped?(identity)') { AMS::Geometry.is_matrix_flipped?(Geom::Transformation.new) }
check(failures, 'AMS::Geometry.get_matrix_scale(scaling(1, 2, 3))') { AMS::Geometry.get_matrix_scale(Geom::Transformation.scaling(1, 2, 3)).to_a }
check(failures, 'AMS::Geometry.extract_matrix_scale(scaling(1, 2, 3))') {
  AMS::Geometry.get_matrix_scale(AMS::Geometry.extract_matrix_scale(Geom::Transformation.scaling(1, 2, 3))).to_a
}
check(failures, 'AMS::Geometry.points_coplanar?(quad)') { AMS::Geometry.points_coplanar?(QUAD) }
check(failures, 'AMS::Geometry.points_coplanar?(3d)') {
  AMS::Geometry.points_coplanar?(QUAD + [Geom::Point3d.new(0, 0, 1)])
}

puts '== AMS::Group (geometry helpers) =='
check(failures, 'AMS::Group.get_definition(group)') { AMS::Group.get_definition(plain_group).class }
check(failures, 'AMS::Group.get_entities(group).count') { AMS::Group.get_entities(plain_group).count }
check(failures, 'AMS::Group.get_bounding_box_from_faces(group)') {
  bbox = AMS::Group.get_bounding_box_from_faces(plain_group)
  [bbox.min.to_a, bbox.max.to_a]
}
check(failures, 'AMS::Group.get_vertices_from_faces(group).size') { AMS::Group.get_vertices_from_faces(plain_group).size }
check(failures, 'AMS::Group.get_polygons_from_faces(group)') { AMS::Group.get_polygons_from_faces(plain_group).map(&:size) }
check(failures, 'AMS::Group.get_triangular_mesh(group).count_polygons') { AMS::Group.get_triangular_mesh(plain_group).count_polygons }
check(failures, 'AMS::Group.get_triangular_meshes(group).size') { AMS::Group.get_triangular_meshes(plain_group).size }
check(failures, 'AMS::Group.get_vertices_from_faces2(group)') { AMS::Group.get_vertices_from_faces2(plain_group).map(&:size) }
check(failures, 'AMS::Group.get_entities(model)') { AMS::Group.get_entities(Sketchup.active_model).class }
check(failures, 'AMS::Group.get_bounding_box_from_faces(nested)') {
  bbox = AMS::Group.get_bounding_box_from_faces(nested_group)
  [bbox.min.to_a, bbox.max.to_a]
}
check(failures, 'AMS::Group.get_vertices_from_faces(nested).size') { AMS::Group.get_vertices_from_faces(nested_group).size }
check(failures, 'AMS::Group.get_vertices_from_faces(group, &validation)') {
  AMS::Group.get_vertices_from_faces(plain_group, true, nil) { |_entity| true }.size
}
check(failures, 'AMS::Group.get_vertices_from_faces(rejected)') {
  AMS::Group.get_vertices_from_faces(plain_group, true, nil) { |_entity| false }.size
}
check(failures, 'AMS::Group.get_vertices_from_faces(group, tra)') {
  AMS::Group.get_vertices_from_faces(plain_group, true, Geom::Transformation.translation(0, 0, 5)).map(&:z)
}

puts '== messageboxes =='
check(failures, 'AMS::Sketchup.messagebox("test") returns IDYES/IDOK') { AMS::Sketchup.messagebox('test') }
check(failures, 'AMS::Sketchup.threaded_messagebox("test")') { AMS::Sketchup.threaded_messagebox('test') }

puts
if failures.empty?
  puts "== ALL #{$checks} AMS FALLBACK CHECKS PASSED =="
else
  puts "== #{failures.size} of #{$checks} CHECKS FAILED =="
  failures.each { |failure| puts "   - #{failure}" }
  raise 'HARNESS TESTS FAILED'
end
