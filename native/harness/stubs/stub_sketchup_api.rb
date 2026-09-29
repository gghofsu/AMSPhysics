# Minimal stub of the SketchUp Ruby API, used by the development harness to
# load MSPhysics / AMS Library outside of SketchUp (see native/harness/README.md).
#
# It is NOT part of the extension; it only has to be complete enough for the
# Ruby files of this repository to load and for the pure Ruby parts of AMS
# Library to be exercised.

# Make the harness behave like 64 bit SketchUp on Windows, which is where the
# Windows Ruby 3.2 native libraries are staged.
if defined?(RUBY_PLATFORM) && RUBY_PLATFORM.to_s =~ /wasi/
  Object.send(:remove_const, :RUBY_PLATFORM)
  RUBY_PLATFORM = 'x64-mingw32'.freeze
end

module StubSketchUp
  # Native extensions that are not available in the harness.
  NATIVE_EXTENSIONS = %w[msp_lib ams_lib].freeze

  # Stand-in for the MSPhysics native classes; the real msp_lib cannot be
  # loaded outside of SketchUp, so the fake API is required instead.
  def self.load_native_stub(path)
    return unless File.basename(path.to_s) =~ /\Amsp_lib/
    return if @native_stub_loaded
    @native_stub_loaded = true
    Kernel.stub_original_require('stub_msphysics_native')
  end

  def self.native_extension?(path)
    path = path.to_s
    # Only actual native library files are skipped; plain Ruby files and
    # directories of the same name (e.g. the ams_lib folder) are loaded.
    return false unless path =~ /\.(so|bundle|dll|dylib)\z/
    NATIVE_EXTENSIONS.include?(File.basename(path).sub(/\..*\z/, ''))
  end
end

# Pretend to load the native extensions, which cannot be loaded outside of
# SketchUp.
module Kernel
  class << self
    alias stub_original_require require unless respond_to?(:stub_original_require)
    alias stub_original_load load unless respond_to?(:stub_original_load)

    def require(path)
      if StubSketchUp.native_extension?(path)
        StubSketchUp.load_native_stub(path)
        return true
      end
      stub_original_require(path)
    end

    def load(path, wrap = false)
      return true if StubSketchUp.native_extension?(path)
      stub_original_load(path, wrap)
    end
  end

  private

  def require(path)
    Kernel.require(path)
  end

  def load(path, wrap = false)
    Kernel.load(path, wrap)
  end
end

class Numeric
  def degrees; self * 180.0 / Math::PI; end
  def radians; self * Math::PI / 180.0; end
  def to_l; self * 0.0254; end
  def to_inch; self * 0.0254; end
  def inch; self * 0.0254; end
  def feet; self * 0.3048; end
  def cm; self * 0.01; end
  def mm; self * 0.001; end
  def m; self; end
end

module StubAttributes
  def attribute_dictionaries
    @attribute_dictionaries ||= MockAttributeDictionaries.new
  end

  def attribute_dictionary(name, create = false)
    create ? attribute_dictionaries.add(name) : attribute_dictionaries[name]
  end

  def set_attribute(dict_name, key, value)
    return true if value.nil?
    attribute_dictionaries.add(dict_name)[key] = value
    true
  end

  def get_attribute(dict_name, key, default = nil)
    dictionary = attribute_dictionaries[dict_name]
    dictionary.nil? ? default : dictionary.get(key, default)
  end
end

class MockAttributeDictionary
  def initialize; @data = {}; end
  def keys; @data.keys; end
  def length; @data.length; end
  def [](key); @data[key]; end
  def get(key, default = nil); @data.key?(key) ? @data[key] : default; end
  def []=(key, value); @data[key] = value; end
  def each(&block); @data.each(&block); end
  def each_pair(&block); @data.each_pair(&block); end
  def delete_key(key); @data.delete(key); end
  def empty?; @data.empty?; end
end

class MockAttributeDictionaries
  include Enumerable
  def initialize; @data = {}; end
  def [](name); @data[name]; end
  def add(name); @data[name] ||= MockAttributeDictionary.new; end
  def each(&block); @data.each(&block); end
  def keys; @data.keys; end
  def length; @data.length; end
  def count; @data.count; end
  def delete(name); @data.delete(name); end
  def empty?; @data.empty?; end
end

# A collection of entities, materials, layers, etc.
class MockCollection
  include Enumerable
  def initialize(items = []); @items = items; end
  def each(&block); @items.each(&block); end
  def [](index); @items[index]; end
  def add(item); @items << item; item; end
  def length; @items.size; end
  def count; @items.size; end
  def size; @items.size; end
  def empty?; @items.empty?; end
  def include?(item); @items.include?(item); end
  def to_a; @items.dup; end
  def first; @items.first; end
  def last; @items.last; end
  def index(item); @items.index(item); end
  def delete(item); @items.delete(item); end
  def remove(item); @items.delete(item); end
  def clear; @items.clear; end
  def purge_unused; 0; end
  def at(index); @items[index]; end
end

class MockOptionsProvider
  def initialize(data = {}); @data = data; end
  def [](key); @data[key]; end
  def []=(key, value); @data[key] = value; end
  def each(&block); @data.each(&block); end
  def keys; @data.keys; end
  def each_pair(&block); @data.each_pair(&block); end
end

class MockOptionsManager
  def initialize(data = {}); @providers = data; end
  def [](name); @providers[name] ||= MockOptionsProvider.new; end
  def each(&block); @providers.each(&block); end
  def keys; @providers.keys; end
end

class MockEntity
  include StubAttributes
  attr_accessor :visible
  def initialize
    @visible = true
  end
  def valid?; true; end
  def deleted?; false; end
  def model; ::Sketchup.active_model; end
  def typename; self.class.name.split('::').last; end
end

module Geom
  class Point3d
    attr_accessor :x, :y, :z
    def initialize(*args)
      args = args.first if args.size == 1 && args.first.is_a?(Array)
      if args.size == 1 && args.first.is_a?(Point3d)
        args = [args.first.x, args.first.y, args.first.z]
      end
      @x, @y, @z = args[0].to_f, args[1].to_f, args[2].to_f
    end
    def [](index); [@x, @y, @z][index]; end
    def [](index, length); to_a[index, length]; end
    def to_a; [@x, @y, @z]; end
    def to_s; "Point3d(#{@x}, #{@y}, #{@z})"; end
    def inspect; to_s; end
    def +(other); Point3d.new(@x + other.x, @y + other.y, @z + other.z); end
    def -(other)
      other.is_a?(Point3d) ? Vector3d.new(@x - other.x, @y - other.y, @z - other.z) : Point3d.new(@x - other.x, @y - other.y, @z - other.z)
    end
    def *(factor); Point3d.new(@x * factor, @y * factor, @z * factor); end
    def /(factor); Point3d.new(@x / factor, @y / factor, @z / factor); end
    def distance(other); Math.sqrt((@x - other.x)**2 + (@y - other.y)**2 + (@z - other.z)**2); end
    def distance_to_plane(plane); 0.0; end
    def offset(vector, distance = 1.0); Point3d.new(@x + vector.x * distance, @y + vector.y * distance, @z + vector.z * distance); end
    def offset!(vector, distance = 1.0)
      @x += vector.x * distance; @y += vector.y * distance; @z += vector.z * distance
      self
    end
    def transform(transformation); transformation * self; end
    def transform!(transformation)
      result = transformation * self
      @x, @y, @z = result.x, result.y, result.z
      self
    end
    def ==(other); other.is_a?(Point3d) && @x == other.x && @y == other.y && @z == other.z; end
    def eql?(other); self == other; end
    def hash; to_a.hash; end
    def project_to_line(*args); self; end
    def on_line?(*args); false; end
    def on_plane?(*args); false; end
    def vector_to(other); Vector3d.new(other.x - @x, other.y - @y, other.z - @z); end
    def clone; Point3d.new(@x, @y, @z); end
    def linear_combination(*args); self; end
    def self.linear_combination(*args); Point3d.new; end
  end

  class Vector3d
    attr_accessor :x, :y, :z
    def initialize(*args)
      args = args.first if args.size == 1 && args.first.is_a?(Array)
      if args.size == 1 && args.first.is_a?(Vector3d)
        args = [args.first.x, args.first.y, args.first.z]
      end
      @x, @y, @z = args[0].to_f, args[1].to_f, args[2].to_f
    end
    def [](index); [@x, @y, @z][index]; end
    def [](index, length); to_a[index, length]; end
    def to_a; [@x, @y, @z]; end
    def to_s; "Vector3d(#{@x}, #{@y}, #{@z})"; end
    def inspect; to_s; end
    def +(other); Vector3d.new(@x + other.x, @y + other.y, @z + other.z); end
    def -(other); Vector3d.new(@x - other.x, @y - other.y, @z - other.z); end
    def *(factor); Vector3d.new(@x * factor, @y * factor, @z * factor); end
    def /(factor); Vector3d.new(@x / factor, @y / factor, @z / factor); end
    def -@; Vector3d.new(-@x, -@y, -@z); end
    def reverse; Vector3d.new(-@x, -@y, -@z); end
    def reverse!; @x = -@x; @y = -@y; @z = -@z; self; end
    def normalize; n = length; n == 0 ? Vector3d.new(@x, @y, @z) : Vector3d.new(@x / n, @y / n, @z / n); end
    def normalize!; v = normalize; @x, @y, @z = v.x, v.y, v.z; self; end
    def length; Math.sqrt(@x * @x + @y * @y + @z * @z); end
    def dot(other); @x * other.x + @y * other.y + @z * other.z; end
    def cross(other); Vector3d.new(@y * other.z - @z * other.y, @z * other.x - @x * other.z, @x * other.y - @y * other.x); end
    def angle_between(other); Math.acos([[-1.0, 1.0].min, dot(other.normalize), 1.0].max); end
    def axes
      n = normalize
      if n.x.abs < 0.9
        xaxis = Vector3d.new(0, -n.z, n.y).normalize
      else
        xaxis = Vector3d.new(-n.z, 0, n.x).normalize
      end
      yaxis = n.cross(xaxis)
      [xaxis, yaxis]
    end
    def transform(transformation); transformation * self; end
    def transform!(transformation)
      v = transformation * self
      @x, @y, @z = v.x, v.y, v.z
      self
    end
    def valid?; true; end
    def ==(other); other.is_a?(Vector3d) && @x == other.x && @y == other.y && @z == other.z; end
    def clone; Vector3d.new(@x, @y, @z); end
    def linear_combination(*args); self; end
    def self.linear_combination(*args); Vector3d.new; end
  end

  class Transformation
    # Row major 4x4 matrix: [xaxis.x, yaxis.x, zaxis.x, origin.x, xaxis.y, ...]
    IDENTITY = [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0].freeze

    def initialize(*args)
      if args.empty?
        @m = IDENTITY.dup
      elsif args.size == 1 && args[0].is_a?(Array)
        @m = args[0].map { |v| v.to_f }
      elsif args.size == 1 && args[0].is_a?(Point3d)
        p = args[0]
        @m = [1.0, 0.0, 0.0, p.x, 0.0, 1.0, 0.0, p.y, 0.0, 0.0, 1.0, p.z, 0.0, 0.0, 0.0, 1.0]
      elsif args.size == 3 && args[0].is_a?(Point3d)
        @m = axis_matrix(args[0], args[1], args[2])
      elsif args.size == 4
        xaxis, yaxis, zaxis, origin = args
        @m = [xaxis.x, yaxis.x, zaxis.x, origin.x, xaxis.y, yaxis.y, zaxis.y, origin.y,
              xaxis.z, yaxis.z, zaxis.z, origin.z, 0.0, 0.0, 0.0, 1.0]
      else
        @m = IDENTITY.dup
      end
    end

    def axis_matrix(origin, zaxis, xaxis = nil)
      z = zaxis.normalize
      x = xaxis ? (xaxis - z * xaxis.dot(z)).normalize : z.axes[0]
      y = z.cross(x)
      [x.x, y.x, z.x, origin.x, x.y, y.y, z.y, origin.y, x.z, y.z, z.z, origin.z, 0.0, 0.0, 0.0, 1.0]
    end
    private :axis_matrix

    def matrix; @m; end
    def to_a; @m.dup; end
    def origin; Point3d.new(@m[3], @m[7], @m[11]); end
    def xaxis; Vector3d.new(@m[0], @m[4], @m[8]); end
    def yaxis; Vector3d.new(@m[1], @m[5], @m[9]); end
    def zaxis; Vector3d.new(@m[2], @m[6], @m[10]); end
    def determinant
      @m[0] * (@m[5] * @m[10] - @m[6] * @m[9]) - @m[1] * (@m[4] * @m[10] - @m[6] * @m[8]) + @m[2] * (@m[4] * @m[9] - @m[5] * @m[8])
    end
    def valid?; true; end
    def identity?
      @m == IDENTITY
    end

    def *(other)
      case other
      when Transformation
        b = other.matrix
        result = Array.new(16)
        for i in 0...4
          for j in 0...4
            result[i * 4 + j] = (0...4).inject(0.0) { |sum, k| sum + @m[i * 4 + k] * b[k * 4 + j] }
          end
        end
        Transformation.new(result)
      when Point3d
        Point3d.new(
          @m[0] * other.x + @m[1] * other.y + @m[2] * other.z + @m[3],
          @m[4] * other.x + @m[5] * other.y + @m[6] * other.z + @m[7],
          @m[8] * other.x + @m[9] * other.y + @m[10] * other.z + @m[11]
        )
      when Vector3d
        Vector3d.new(
          @m[0] * other.x + @m[1] * other.y + @m[2] * other.z,
          @m[4] * other.x + @m[5] * other.y + @m[6] * other.z,
          @m[8] * other.x + @m[9] * other.y + @m[10] * other.z
        )
      when Array
        Transformation.new(other).pre_transform(self)
      else
        other
      end
    end

    def pre_transform(other); other * self; end

    def inverse
      raise ArgumentError, 'Transformation is not invertible' if determinant.abs < 1.0e-12
      a = @m.each_slice(4).map(&:dup)
      inv = Array.new(4) { |i| Array.new(4) { |j| i == j ? 1.0 : 0.0 } }
      for i in 0...4
        pivot = (i...4).max_by { |r| a[r][i].abs }
        a[i], a[pivot] = a[pivot], a[i]
        inv[i], inv[pivot] = inv[pivot], inv[i]
        factor = a[i][i]
        for j in 0...4
          a[i][j] /= factor
          inv[i][j] /= factor
        end
        for r in 0...4
          next if r == i
          factor = a[r][i]
          for j in 0...4
            a[r][j] -= factor * a[i][j]
            inv[r][j] -= factor * inv[i][j]
          end
        end
      end
      Transformation.new(inv.flatten)
    end

    def invert!
      result = inverse.matrix
      @m = result
      self
    end

    def to_s; "Transformation(#{@m.join(', ')})"; end
    def inspect; '#<Geom::Transformation>'; end
    def clone; Transformation.new(@m.dup); end
    def ==(other); other.is_a?(Transformation) && @m == other.matrix; end

    def self.rotation(origin, axis, angle)
      if axis.is_a?(Numeric) && angle.is_a?(Vector3d)
        origin, axis, angle = Point3d.new, origin, axis
      end
      c = Math.cos(angle)
      s = Math.sin(angle)
      t = 1.0 - c
      x, y, z = axis.normalize.x, axis.normalize.y, axis.normalize.z
      r = [t * x * x + c, t * x * y - s * z, t * x * z + s * y, 0.0,
           t * x * y + s * z, t * y * y + c, t * y * z - s * x, 0.0,
           t * x * z - s * y, t * y * z + s * x, t * z * z + c, 0.0,
           0.0, 0.0, 0.0, 1.0]
      Transformation.new(origin) * Transformation.new(r) * Transformation.new(Point3d.new(-origin.x, -origin.y, -origin.z))
    end

    def self.translation(*args)
      args = args.first if args.size == 1 && args.first.is_a?(Array)
      Transformation.new(Point3d.new(args[0].to_f, args[1].to_f, args[2].to_f))
    end

    def self.scaling(*args)
      args = args.first if args.size == 1 && args.first.is_a?(Array)
      if args.size == 1
        s = args[0].to_f
        args = [s, s, s]
      end
      Transformation.new([args[0].to_f, 0, 0, 0, 0, args[1].to_f, 0, 0, 0, 0, args[2].to_f, 0, 0, 0, 0, 1])
    end

    def self.axes(*args)
      args.size == 3 ? Transformation.new(args[0], args[1], args[2]) : Transformation.new(*args)
    end

    def self.interpolate(from, to, factor)
      ax = from.xaxis + (to.xaxis - from.xaxis) * factor
      ay = from.yaxis + (to.yaxis - from.yaxis) * factor
      az = from.zaxis + (to.zaxis - from.zaxis) * factor
      ao = from.origin + (to.origin - from.origin) * factor
      Transformation.new(ax, ay, az, ao)
    end
  end

  class BoundingBox
    def initialize(*args)
      @points = []
      @points.concat(args.first) if args.first.is_a?(Array)
    end
    def add(*args)
      args.flatten.each { |point| @points << point if point.is_a?(Point3d) }
      self
    end
    def empty?; @points.empty?; end
    def valid?; !@points.empty?; end
    def min
      return Point3d.new if @points.empty?
      Point3d.new(@points.map(&:x).min, @points.map(&:y).min, @points.map(&:z).min)
    end
    def max
      return Point3d.new if @points.empty?
      Point3d.new(@points.map(&:x).max, @points.map(&:y).max, @points.map(&:z).max)
    end
    def center
      low, high = min, max
      Point3d.new((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, (low.z + high.z) * 0.5)
    end
    def corner(index = 0)
      index = index.to_i
      Point3d.new((index & 1) == 0 ? min.x : max.x, (index & 2) == 0 ? min.y : max.y, (index & 4) == 0 ? min.z : max.z)
    end
    def width; max.x - min.x; end
    def height; max.y - min.y; end
    def depth; max.z - min.z; end
    def diag; (max - min).length; end
    def contains?(point)
      return false if @points.empty?
      point.x >= min.x && point.x <= max.x && point.y >= min.y && point.y <= max.y && point.z >= min.z && point.z <= max.z
    end
    def intersect(*args); self; end
    def to_a; [min, max]; end
    def self.diagonal(*args); 0.0; end
  end

  class PolygonMesh
    def initialize(*args)
      @points = []
      @polygons = []
    end
    def add_point(point); @points << point; @points.size - 1; end
    def add_polygon(*points)
      points = points.first if points.size == 1 && points.first.is_a?(Array)
      @polygons << points.map { |point| add_point(point) }
      nil
    end
    def points; @points; end
    def polygons; @polygons; end
    def point_at(index); @points[index]; end
    def point_index(point); @points.index(point); end
    def count_points; @points.size; end
    def count_polygons; @polygons.size; end
    def transform!(transformation); @points = @points.map { |point| transformation * point }; self; end
    def valid?; nil; end
    def set_point(index, point); @points[index] = point; end
    def set_uv(*args); end
    def uv_at(*args); nil; end
    def normal_at(index); Vector3d.new(0, 0, 1); end
  end
end

# Top level constants of the SketchUp Ruby API.
ORIGIN    = Geom::Point3d.new(0, 0, 0)
ORIGIN_2D = Geom::Point3d.new(0, 0)
X_AXIS    = Geom::Vector3d.new(1, 0, 0)
Y_AXIS    = Geom::Vector3d.new(0, 1, 0)
Z_AXIS    = Geom::Vector3d.new(0, 0, 1)
X_AXIS_2D = Geom::Vector3d.new(1, 0, 0)
Y_AXIS_2D = Geom::Vector3d.new(0, 1, 0)

MB_OK                = 0
MB_OKCANCEL          = 1
MB_ABORTRETRYIGNORE  = 2
MB_YESNOCANCEL       = 3
MB_YESNO             = 4
MB_RETRYCANCEL       = 5
IDOK                 = 1
IDCANCEL             = 2
IDABORT              = 3
IDRETRY              = 4
IDIGNORE             = 5
IDYES                = 6
IDNO                 = 7

MF_ENABLED  = 0
MF_GRAYED   = 1
MF_DISABLED = 2

GL_POINTS = 0
GL_LINES = 1

module Sketchup
  class Color
    attr_accessor :red, :green, :blue, :alpha
    def initialize(*args)
      if args.size == 3 || args.size == 4
        @red, @green, @blue, @alpha = (args + [255])[0, 4].map { |v| v.to_i }
      elsif args.size == 1 && args[0].is_a?(String)
        hex = args[0].sub('#', '')
        @red = hex[0, 2].to_i(16)
        @green = hex[2, 2].to_i(16)
        @blue = hex[4, 2].to_i(16)
        @alpha = hex.length >= 8 ? hex[6, 2].to_i(16) : 255
      else
        @red = @green = @blue = 0
        @alpha = 255
      end
    end
    def self.new_from_name(name)
      idx = (name.to_s.hash.abs % 200) + 1
      new(idx % 256, (idx * 7) % 256, (idx * 13) % 256)
    end
    def to_i; (@red << 24) | (@green << 16) | (@blue << 8) | @alpha; end
    def ==(other); other.is_a?(Color) && to_i == other.to_i; end
    def to_a; [@red, @green, @blue, @alpha]; end
    def to_s; "Color(#{@red}, #{@green}, #{@blue}, #{@alpha})"; end
  end

  class Entity < MockEntity
    def to_s; "#<Sketchup::#{self.class.name.split('::').last}>"; end
  end

  class Drawingelement < Entity; end
  class Edge < Drawingelement
    def start; Geom::Point3d.new; end
    def end; Geom::Point3d.new; end
    def vertices; []; end
    def curve; nil; end
    def soft?; false; end
    def smooth?; false; end
  end
  class Face < Drawingelement
    def vertices; []; end
    def edges; []; end
    def loops; []; end
    def outer_loop; nil; end
    def mesh(flags = 0); Geom::PolygonMesh.new; end
    def normal; Z_AXIS; end
    def area; 0.0; end
    def transformation; Geom::Transformation.new; end
    def material; nil; end
    def back_material; nil; end
    def plane; [ORIGIN, Z_AXIS]; end
    def get_gl_normal(*args); [0.0, 0.0, 1.0]; end
  end
  class Vertex < Drawingelement
    def position; Geom::Point3d.new; end
  end
  class Text < Drawingelement; end

  class Entities < MockCollection
    def add_face(*args); Face.new; end
    def add_line(*args); Edge.new; end
    def add_edges(*args); []; end
    def add_group(*args); Group.new; end
    def add_instance(definition, transformation = nil); ComponentInstance.new(definition || ComponentDefinition.new); end
    def add_circle(*args); []; end
    def add_arc(*args); []; end
    def add_curve(*args); []; end
    def add_edges(*args); []; end
    def add_dimension_linear(*args); nil; end
    def add_text(*args); Text.new; end
    def transform_entities(transformation, entities = nil); true; end
    def intersect_with(*args); false; end
    def erase_entities(*args); true; end
    def model; ::Sketchup.active_model; end
    def active_section_planes; MockCollection.new; end
  end

  class ComponentDefinition < Entity
    attr_accessor :name
    attr_reader :entities, :instances
    def initialize(name = nil)
      @name = name || 'Definition'
      @entities = Entities.new
      @instances = MockCollection.new
      @attribute_dictionaries = MockAttributeDictionaries.new
    end
    def valid?; true; end
    def count_instances; @instances.size; end
    def group?; false; end
    def image?; false; end
    def manifold?; false; end
  end

  class Group < Entity
    attr_accessor :name, :material, :layer, :transformation, :visible
    attr_reader :entities
    def initialize
      @entities = Entities.new
      @transformation = Geom::Transformation.new
      @visible = true
      @attribute_dictionaries = MockAttributeDictionaries.new
    end
    def definition; @definition ||= ComponentDefinition.new('Group'); end
    def group; self; end
    def move!(transformation)
      @transformation = transformation * @transformation
      self
    end
    def transform!(transformation)
      @transformation = transformation * @transformation
      self
    end
    def explode; MockCollection.new; end
    def locked?; false; end
    def valid?; true; end
    def bounds; Geom::BoundingBox.new; end
    def manifold?; false; end
  end

  class ComponentInstance < Entity
    attr_accessor :name, :material, :layer, :transformation, :visible
    attr_reader :definition
    def initialize(definition = nil)
      @definition = definition || ComponentDefinition.new
      @transformation = Geom::Transformation.new
      @visible = true
      @attribute_dictionaries = MockAttributeDictionaries.new
    end
    def group; nil; end
    def move!(transformation)
      @transformation = transformation * @transformation
      self
    end
    def transform!(transformation)
      @transformation = transformation * @transformation
      self
    end
    def explode; MockCollection.new; end
    def locked?; false; end
    def valid?; true; end
    def bounds; Geom::BoundingBox.new; end
    def manifold?; false; end
    def definition=(definition); @definition = definition; end
  end

  class Material < Entity
    attr_accessor :name, :color, :alpha, :texture, :colorize_type
    def initialize(name = nil)
      @name = name || 'Material'
      @color = Color.new(200, 200, 200)
      @alpha = 1.0
      @colorize_type = 0
      @attribute_dictionaries = MockAttributeDictionaries.new
    end
    def valid?; true; end
    def texture; @texture; end
    def display_name; @name; end
  end

  class Layer < Entity
    attr_accessor :name, :color, :visible, :page_behavior
    def initialize(name = nil)
      @name = name || 'Layer0'
      @color = Color.new(0, 0, 0)
      @visible = true
    end
    def valid?; true; end
    def display_name; @name; end
  end

  class Layers < MockCollection
    def add(name); layer = Layer.new(name); add_item(layer); layer; end
    def add_item(layer); @items << layer; layer; end
    def unique_name(base = 'Layer'); base; end
    def at(index); @items[index]; end
  end

  class Materials < MockCollection
    def add(name = nil); material = Material.new(name); @items << material; material; end
    def at(index); @items[index]; end
    def current; @current ||= add('Default'); end
    def current=(material); @current = material; end
  end

  class Style < Entity
    attr_accessor :name
    def initialize(name = nil); @name = name || 'Style'; end
    def valid?; true; end
  end

  class Styles < MockCollection
    def initialize
      super
      @items = [Style.new('Default')]
      @selected_style = @items.first
    end
    def selected_style; @selected_style; end
    def selected_style=(style); @selected_style = style; end
    def active_style; @selected_style; end
    def add_style(*args); Style.new; end
    def each(&block); @items.each(&block); end
    def length; @items.size; end
  end

  class Camera
    attr_accessor :eye, :target, :up, :perspective, :focal_length, :fov, :image_width, :height, :aspect_ratio
    def initialize(*args)
      @eye = Geom::Point3d.new(0, 0, 10)
      @target = Geom::Point3d.new(0, 0, 0)
      @up = Geom::Vector3d.new(0, 1, 0)
      @perspective = true
      @focal_length = 50.0
      @fov = 35.0
      @image_width = 36.0
      @height = 10.0
      @aspect_ratio = 1.0
    end
    def set(eye, target, up = nil)
      @eye = Geom::Point3d.new(eye)
      @target = Geom::Point3d.new(target)
      @up = Geom::Vector3d.new(up) if up
      self
    end
    def perspective?; @perspective; end
    def direction; (@target - @eye).normalize; end
    def xaxis; direction.axes[0]; end
    def yaxis; direction.axes[1]; end
    def center_2d; Geom::Point3d.new(0, 0); end
    def corner_2d(*args); Geom::Point3d.new(0, 0); end
    def eye=(value); @eye = Geom::Point3d.new(value); end
    def target=(value); @target = Geom::Point3d.new(value); end
    def up=(value); @up = Geom::Vector3d.new(value); end
    def valid?; true; end
  end

  class View
    attr_accessor :camera
    def initialize
      @camera = Camera.new
      @drawing_color = nil
      @line_width = 1
      @line_stipple = 0
    end
    def vpwidth; 1000; end
    def vpheight; 800; end
    def center; Geom::Point3d.new(500, 400); end
    def corner(index); Geom::Point3d.new(0, 0); end
    def draw(*args); end
    def draw2d(*args); end
    def draw_line(*args); end
    def draw_lines(*args); end
    def draw_points(*args); end
    def draw_polyline(*args); end
    def drawing_color; @drawing_color; end
    def drawing_color=(color); @drawing_color = color; end
    def line_width; @line_width; end
    def line_width=(width); @line_width = width; end
    def line_stipple; @line_stipple; end
    def line_stipple=(stipple); @line_stipple = stipple; end
    def invalidate; true; end
    def pick_helper(*args); nil; end
    def inputpoint(*args); InputPoint.new; end
    def screen_coords(point); Geom::Point3d.new(0, 0); end
    def write_image(*args); true; end
    def model; ::Sketchup.active_model; end
  end

  class InputPoint < Entity
    def position; Geom::Point3d.new; end
    def pick(*args); nil; end
    def valid?; true; end
    def degrees_of_freedom; 3; end
    def display?; false; end
  end

  class Selection < MockCollection
    def clear; @items.clear; end
    def add(*args); args.each { |item| @items << item }; args.size; end
    def remove(*args); args.each { |item| @items.delete(item) }; nil; end
    def to_a; @items.dup; end
    def empty?; @items.empty?; end
    def length; @items.size; end
    def [](index); @items[index]; end
    def each(&block); @items.each(&block); end
    def add_observer(observer); true; end
    def remove_observer(observer); true; end
  end

  class ShadowInfo
    def initialize(data = {})
      @data = {
        'City' => Sketchup.active_model ? 'Ithaca' : 'Ithaca',
        'Country' => 'United States',
        'Dark' => 20,
        'DayOfYear' => 172,
        'DaylightSavings' => false,
        'DisplayNorth' => false,
        'DisplayOnAllFaces' => true,
        'DisplayOnGroundPlane' => true,
        'DisplayShadows' => true,
        'EdgesCastShadows' => true,
        'Latitude' => 42.4,
        'Light' => 80,
        'Longitude' => -76.5,
        'NorthAngle' => 0.0,
        'ShadowTime' => Time.at(1_000_000_000),
        'ShadowTime_time_t' => 1_000_000_000,
        'SunDirection' => Geom::Vector3d.new(1, 1, 1).normalize,
        'SunRise' => Time.at(1_000_000_000),
        'SunRise_time_t' => 1_000_000_000,
        'SunSet' => Time.at(1_000_000_000),
        'SunSet_time_t' => 1_000_000_000,
        'TZOffset' => -5.0,
        'UseSunForAllShading' => false,
      }.merge(data)
    end
    def [](key); @data[key]; end
    def []=(key, value); @data[key] = value; end
    def each(&block); @data.each(&block); end
    def each_pair(&block); @data.each_pair(&block); end
    def each_key(&block); @data.each_key(&block); end
    def keys; @data.keys; end
    def values; @data.values; end
    def length; @data.length; end
    def count; @data.size; end
    def size; @data.size; end
    def to_a; @data.to_a; end
    def include?(key); @data.key?(key); end
    def self.keys; new.keys; end
  end

  class RenderingOptions
    def initialize(data = {})
      @data = {
        'BackgroundColor' => Color.new(255, 255, 255),
        'BandColor' => Color.new(0, 0, 0),
        'ConstructionColor' => Color.new(0, 0, 0),
        'DisplayColorByLayer' => false,
        'DisplayFog' => false,
        'FogColor' => Color.new(192, 192, 192),
        'FogDist' => 100.0,
        'FogUseCamera' => false,
        'ForegroundColor' => Color.new(0, 0, 0),
        'FrontColor' => Color.new(255, 255, 255),
        'HighlightColor' => Color.new(0, 0, 255),
        'LineEndWidth' => 1,
        'LineExtension' => 0,
        'LockedColor' => Color.new(255, 0, 0),
        'RenderMode' => 1,
        'SectionActiveColor' => Color.new(0, 0, 0),
        'SectionCutWidth' => 1,
        'SectionDefaultCutColor' => Color.new(0, 0, 0),
        'SectionInactiveColor' => Color.new(0, 0, 0),
        'Shaded' => true,
        'SkyColor' => Color.new(255, 255, 255),
        'Texture' => true,
      }.merge(data)
    end
    def [](key); @data[key]; end
    def []=(key, value); @data[key] = value; end
    def each(&block); @data.each(&block); end
    def each_pair(&block); @data.each_pair(&block); end
    def keys; @data.keys; end
    def length; @data.length; end
    def count; @data.size; end
    def size; @data.size; end
    def to_a; @data.to_a; end
  end

  class Page < Entity
    attr_accessor :name, :transition_time, :delay_time, :use_camera, :use_hidden,
                  :use_hidden_layers, :use_rendering_options, :use_style,
                  :use_shadow_info, :use_axes, :use_section_planes
    attr_reader :camera, :rendering_options, :shadow_info, :axes, :style, :hidden_entities, :layers
    def initialize(name = 'Page')
      @name = name
      @transition_time = 0.0
      @delay_time = 0.0
      @camera = ::Sketchup.active_model ? ::Sketchup.active_model.active_view.camera : Sketchup::Camera.new
      @rendering_options = MockOptionsProvider.new
      @shadow_info = MockOptionsProvider.new
      @axes = nil
      @style = nil
      @hidden_entities = []
      @layers = []
      @use_camera = true
      @use_hidden = true
      @use_hidden_layers = true
      @use_rendering_options = true
      @use_style = true
      @use_shadow_info = true
      @use_axes = true
      @use_section_planes = true
    end
    def camera=(camera); @camera = camera; end
    def rendering_options=(options); @rendering_options = options; end
    def shadow_info=(info); @shadow_info = info; end
    def axes=(axes); @axes = axes; end
    def style=(style); @style = style; end
    def use_camera?; @use_camera; end
    def use_hidden?; @use_hidden; end
    def use_hidden_layers?; @use_hidden_layers; end
    def use_rendering_options?; @use_rendering_options; end
    def use_style?; @use_style; end
    def use_shadow_info?; @use_shadow_info; end
    def use_axes?; @use_axes; end
    def use_section_planes?; @use_section_planes; end
    def update(flags = 0); true; end
    def valid?; true; end
  end

  class Pages < MockCollection
    attr_accessor :selected_page
    def initialize
      super
      @selected_page = nil
    end
    def add(name = nil); page = Page.new(name || "Page #{@items.size + 1}"); @items << page; page; end
    def add_page(name = nil); add(name); end
    def [](index); @items[index]; end
    def each(&block); @items.each(&block); end
    def length; @items.size; end
    def size; @items.size; end
    def count; @items.size; end
    def erase(page); @items.delete(page); end
    def unique_name(base); base; end
  end

  class Axes < Entity
    attr_accessor :origin, :xaxis, :yaxis, :zaxis
    def initialize
      @origin = Geom::Point3d.new(0, 0, 0)
      @xaxis = Geom::Vector3d.new(1, 0, 0)
      @yaxis = Geom::Vector3d.new(0, 1, 0)
      @zaxis = Geom::Vector3d.new(0, 0, 1)
    end
    def transformation; Geom::Transformation.new(@xaxis, @yaxis, @zaxis, @origin); end
    def set(origin, xaxis, yaxis); @origin = Geom::Point3d.new(origin); @xaxis = Geom::Vector3d.new(xaxis); @yaxis = Geom::Vector3d.new(yaxis); end
    def to_a; [@origin, @xaxis, @yaxis, @zaxis]; end
    def valid?; true; end
  end

  class Tool
    def activate; end
    def deactivate(view); end
    def onMouseMove(flags, x, y, view); end
    def onLButtonDown(flags, x, y, view); end
    def onLButtonUp(flags, x, y, view); end
    def onKeyDown(key, repeat, flags, view); end
    def onKeyUp(key, repeat, flags, view); end
    def onCancel(reason, view); end
    def draw(view); end
    def getMenu(menu); false; end
  end

  class Tools
    def push_tool(tool); true; end
    def pop_tool; true; end
    def active_tool_name; 'SelectTool'; end
    def add_observer(observer); true; end
  end

  class Behavior
    def no_scale_mask?(value); true; end
    def snaps_to_planes?; true; end
    def always_face_camera?; false; end
    def is2d?; false; end
  end

  class Model < Entity
    attr_reader :entities, :materials, :layers, :pages, :definitions, :styles,
                :rendering_options, :shadow_info, :active_view, :selection, :tools,
                :options, :axes, :behavior, :attribute_dictionaries
    attr_accessor :active_layer

    def initialize
      @entities = Entities.new
      @materials = Materials.new
      @layers = Layers.new
      @pages = Pages.new
      @definitions = MockCollection.new
      @styles = Styles.new
      @rendering_options = RenderingOptions.new
      @shadow_info = ShadowInfo.new
      @active_view = View.new
      @selection = Selection.new
      @tools = Tools.new
      @options = MockOptionsManager.new
      @axes = Axes.new
      @behavior = Behavior.new
      @active_layer = @layers.first
      @attribute_dictionaries = MockAttributeDictionaries.new
      @operation_depth = 0
      @operations = []
    end

    def start_operation(name, disable_ui = false, next_transparent = false, transparent = false)
      @operations << name
      @operation_depth += 1
      true
    end

    def commit_operation
      @operation_depth -= 1 if @operation_depth > 0
      @operations.pop
      true
    end

    def abort_operation
      @operation_depth -= 1 if @operation_depth > 0
      @operations.pop
      true
    end

    def operation_depth; @operation_depth; end

    def active_entities; @entities; end
    def active_path; nil; end
    def bounds; Geom::BoundingBox.new; end
    def raytest(*args); nil; end
    def raycast(*args); nil; end
    def import(*args); 0; end
    def export(*args); true; end
    def save(*args); true; end
    def save_copy(*args); true; end
    def path; '/tmp/harness_model.skp'; end
    def title; 'Untitled'; end
    def name; 'Untitled'; end
    def modified?; false; end
    def valid?; true; end
    def instances; MockCollection.new; end
    def add_observer(observer); true; end
    def remove_observer(observer); true; end
    def place_component(*args); nil; end
    def number_faces; 0; end
    def set_attribute(dict_name, key, value)
      return true if value.nil?
      @attribute_dictionaries.add(dict_name)[key] = value
      true
    end
    def get_attribute(dict_name, key, default = nil)
      dictionary = @attribute_dictionaries[dict_name]
      dictionary.nil? ? default : dictionary.get(key, default)
    end
  end

  class AppObserver
    def onNewModel(model); end
    def onOpenModel(model); end
    def onQuit; end
    def expectsStartupModelNotifications; false; end
  end

  class ModelObserver
    def onActivePathChanged(model); end
    def onAfterComponentSaveAs(model); end
    def onBeforeComponentSaveAs(model); end
    def onDeleteModel(model); end
    def onEraseAll; end
    def onExplode(model); end
    def onNewModel(model); end
    def onOpenModel(model); end
    def onPlaceComponent(instance); end
    def onPostSaveModel(model); end
    def onPreSaveModel(model); end
    def onSaveModel(model); end
    def onTransactionAbort(model); end
    def onTransactionCommit(model); end
    def onTransactionRedo(model); end
    def onTransactionStart(model); end
    def onTransactionUndo(model); end
  end

  class EntitiesObserver
    def onElementAdded(entities, entity); end
    def onElementModified(entities, entity); end
    def onElementRemoved(entities, entity_id); end
    def onEraseAll(entities); end
    def onTransactionAbort(entities); end
    def onTransactionCommit(entities); end
    def onTransactionEmpty(entities); end
    def onTransactionRedo(entities); end
    def onTransactionStart(entities); end
    def onTransactionUndo(entities); end
    def onContentsModified(entities); end
  end

  class SelectionObserver
    def onSelectionAdded(selection, entity); end
    def onSelectionBulkChange(selection); end
    def onSelectionCleared(selection); end
    def onSelectionRemoved(selection, entity); end
  end

  class PagesObserver
    def onContentsModified(pages); end
    def onElementAdded(pages, page); end
    def onElementRemoved(pages, page); end
  end

  class ToolsObserver
    def onActiveToolChanged(tools, tool_name, tool_id); end
    def onToolStateChanged(tools, tool_name, tool_id, tool_state); end
  end

  class ViewObserver
    def onViewChanged(view); end
  end

  class MaterialsObserver
    def onMaterialAdd(materials, material); end
    def onMaterialChange(materials, material); end
    def onMaterialRemove(materials, material); end
  end

  class LayerObserver
    def onLayerAdded(layers, layer); end
    def onLayerChanged(layers, layer); end
    def onLayerRemoved(layers, layer); end
  end
end

module UI
  def self.messagebox(text, type = MB_OK)
    puts "[stub] messagebox: #{text.to_s.split("\n").first}" if ENV['STUB_VERBOSE']
    type == MB_YESNO || type == MB_YESNOCANCEL ? IDYES : IDOK
  end

  def self.openURL(url); true; end
  def self.beep; true; end
  def self.start_timer(interval, repeat = false); 1; end
  def self.stop_timer(id); true; end
  def self.refresh_toolbars; true; end
  def self.scale_factor(*args); 1.0; end
  def self.set_cursor(*args); true; end
  def self.show_extension_warehouse(*args); true; end
  def self.inputbox(*args); nil; end

  def self.menu(name = 'Plugins')
    @menus ||= {}
    @menus[name] ||= StubMenu.new(name)
  end

  def self.toolbar(name = 'Toolbar')
    @toolbars ||= {}
    @toolbars[name] ||= Toolbar.new(name)
  end

  def self.play_sound(*args); true; end
  def self.add_context_menu_handler(&block); true; end
  def self.add_handler(*args, &block); true; end
  def self.create_cursor(*args); 1; end
  def self.set_cursor(*args); true; end
  def self.show_cursor(*args); true; end
  def self.hide_cursor(*args); true; end

  class StubMenu
    def initialize(name); @name = name; @items = []; end
    def add_item(item); @items << item; item; end
    def add_submenu(name); submenu = StubMenu.new(name); @items << submenu; submenu; end
    def add_separator; @items << :separator; end
    def set_validation_proc(*args, &block); true; end
    attr_reader :name, :items
  end

  class Command
    attr_accessor :menu_text, :small_icon, :large_icon, :status_bar_text, :tooltip
    attr_reader :name
    def initialize(name = nil)
      @name = name
      @menu_text = name
      @status_bar_text = name
      @tooltip = name
    end
    def set_validation_proc(*args, &block); true; end
    def menu_text=(text); @menu_text = text; end
    def proc; nil; end
  end

  class Toolbar
    attr_reader :name
    def initialize(name = nil); @name = name || 'Toolbar'; @items = []; end
    def add_item(item); @items << item; item; end
    def add_separator; @items << :separator; end
    def restore; true; end
    def show; true; end
    def hide; true; end
    def visible?; true; end
    def set_validation_proc(*args, &block); true; end
  end

  class HtmlDialog
    attr_reader :name
    def initialize(options = {}, version = nil, *args)
      @options = options.is_a?(Hash) ? options : { title: options.to_s }
      @name = @options[:title] || @options['title'] || 'Dialog'
      @callbacks = {}
    end
    def set_html(*args); true; end
    def set_file(*args); true; end
    def set_url(*args); true; end
    def show(*args); true; end
    def show_modal(*args); true; end
    def close(*args); true; end
    def hide; true; end
    def visible?; true; end
    def center(*args); true; end
    def set_position(*args); true; end
    def set_size(*args); true; end
    def add_action_callback(name, &block); @callbacks[name] = block; true; end
    def remove_action_callback(name); true; end
    def execute_script(*args); true; end
    def get_element_value(*args); nil; end
    def set_element_value(*args); true; end
    def bring_to_front; true; end
    def set_can_close(*args); true; end
    def screen_scale_factor(*args); 1.0; end
  end

  WebDialog = HtmlDialog
end

module Sketchup
  VERSION = '26.2.243'.freeze
  VERSION_NUMBER = 26.2
  VERSION_MAJOR = 26
  VERSION_MINOR = 2

  @active_model = nil

  class << self
    attr_writer :active_model

    def version; VERSION; end
    def version_number; VERSION_NUMBER; end
    def version_major; VERSION_MAJOR; end
    def is_64bit?; true; end
    def is_pro?; true; end
    def is_online?; false; end
    def platform; 'win'; end
    def mdi?; true; end
    def locale; 'en-US'; end
    def get_locale; 'en-US'; end
    def status_text=(text); text; end
    def set_status_text(text); text; end
    def active_model; @active_model; end
    def add_observer(observer); true; end
    def remove_observer(observer); true; end
    def read_default(*args); nil; end
    def write_default(*args); true; end
    def openURL(url); true; end
    def find_support_file(*args); nil; end
    def find_support_files(*args); []; end
    def get_datfile_info(*args); nil; end
    def get_shortcut(*args); nil; end
    def get_default(*args); 0; end
    def get_extensions_dir; '/'; end
    def get_plugins_dir; '/'; end
    def get_resource_path(*args); '/'; end
    def get_sketchup_dir; '/'; end
    def get_user_dir; '/'; end
    def require(path); Kernel.require(path); end
    def load(path); Kernel.load(path); end
    def install_from_archive(*args); true; end
    def register_extension(extension, load_on_start = false)
      # SketchUp loads the extension file of an extension that is registered
      # with load_on_start set to true.
      Kernel.require(extension.path) if load_on_start && extension.path
      true
    end
    def send_action(*args); true; end
    def file_loaded?(path); @loaded_files ||= {}; @loaded_files[path]; end
    def file_loaded(path); @loaded_files ||= {}; @loaded_files[path] = true; end
  end
end

def file_loaded?(path); ::Sketchup.file_loaded?(path); end
def file_loaded(path); ::Sketchup.file_loaded(path); end

# Top level class, normally defined by SketchUp's extensions.rb.
class SketchupExtension
  attr_accessor :name, :description, :version, :copyright, :creator, :folder
  attr_reader :path
  def initialize(name = nil, path = nil)
    @name = name
    @path = path
    @loaded = false
  end
  def loaded?; @loaded; end
  def extension_dir; @path ? File.dirname(@path) : '/'; end
  def register; true; end
  def uncheck; true; end
end

# The harness model has to exist before the stubs of the model itself are
# created, as some of them refer to it.
Sketchup.active_model = Sketchup::Model.new
