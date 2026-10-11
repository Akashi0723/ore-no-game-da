"""Run with Blender to review real extracted native geometry, not Studio graphics.

blender --background --python tools/render_scene.py -- --input .build/world-scene.json
"""
import argparse
import json
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path(".build/world-preview.png"))
    parser.add_argument("--view", choices=("world", "pond", "creatures"), default="world")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    nodes = json.loads(args.input.read_text())["nodes"]
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    convert = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    meshes, materials = {}, {}

    def primitive(shape):
        if shape in meshes:
            return meshes[shape]
        if shape == "Ball":
            bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.5)
        elif shape == "Cylinder":
            bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.5, depth=1)
            for vertex in bpy.context.object.data.vertices:
                old = vertex.co.copy()
                vertex.co = (old.z, old.x, old.y)
        elif shape == "WedgePart":
            mesh = bpy.data.meshes.new("NativeWedge")
            mesh.from_pydata([(-.5, -.5, -.5), (.5, -.5, -.5), (-.5, -.5, .5), (.5, -.5, .5),
                              (-.5, .5, .5), (.5, .5, .5)], [],
                             [(0, 2, 3, 1), (2, 4, 5, 3), (0, 1, 5, 4), (0, 4, 2), (1, 3, 5)])
            meshes[shape] = mesh
            return mesh
        else:
            bpy.ops.mesh.primitive_cube_add(size=1)
        source = bpy.context.object
        mesh = source.data
        if shape in ("Ball", "Cylinder"):
            for polygon in mesh.polygons:
                polygon.use_smooth = True
        bpy.data.objects.remove(source, do_unlink=True)
        meshes[shape] = mesh
        return mesh

    def material(rgb, kind, transparency):
        key = tuple(rgb) + (kind, transparency)
        if key not in materials:
            mat = bpy.data.materials.new("NativeColor")
            mat.use_nodes = True
            shader = mat.node_tree.nodes.get("Principled BSDF")
            # Roblox Color3 uses display-space colors; Blender shading uses linear.
            linear = [channel / 12.92 if channel <= .04045 else ((channel + .055) / 1.055)**2.4 for channel in rgb]
            shader.inputs["Base Color"].default_value = (*linear, 1)
            shader.inputs["Roughness"].default_value = .65
            if kind.endswith("Neon"):
                shader.inputs["Emission Color"].default_value = (*linear, 1)
                shader.inputs["Emission Strength"].default_value = .5
            materials[key] = mat
        return materials[key]

    for node in nodes:
        if node["class"] not in ("Part", "WedgePart", "SpawnLocation"):
            continue
        props = node["properties"]
        transparency = props.get("Transparency", 0)
        if transparency >= .95:
            continue
        shape = "WedgePart" if node["class"] == "WedgePart" else props.get("Shape", "Block").split(".")[-1]
        mesh = primitive(shape)
        obj = bpy.data.objects.new(node["name"], mesh)
        bpy.context.collection.objects.link(obj)
        rotation = props["CFrame"]["rotation"]
        local = Matrix((rotation[:3], rotation[3:6], rotation[6:9]))
        size = props["Size"]["value"]
        transform = (convert @ local @ Matrix.Diagonal(Vector(size))).to_4x4()
        transform.translation = convert @ Vector(props["CFrame"]["position"])
        obj.matrix_world = transform
        rgb = props.get("Color", {"value": [.7, .7, .7]})["value"]
        mat = material(rgb, props.get("Material", ""), transparency)
        # Per-object material slots keep reused primitive meshes lightweight.
        if not obj.data.materials:
            obj.data.materials.append(mat)
        obj.material_slots[0].link = "OBJECT"
        obj.material_slots[0].material = mat

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 40
    # Some cloud Blender builds omit OpenImageDenoise; rendering must still work.
    scene.cycles.use_denoising = False
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 900 if args.view != "creatures" else 780
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.57, .75, .86, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .7
    scene.view_settings.view_transform = "Standard"

    bpy.ops.object.light_add(type="SUN", location=(0, 0, 100))
    light = bpy.context.object
    light.rotation_euler = (.5, -.3, -.4)
    light.data.energy = 2.1
    light.data.angle = .35

    bpy.ops.object.camera_add()
    camera = bpy.context.object
    if args.view == "world":
        position, target, scale = (86, 103, 110), (33, 18, -38), 267
    elif args.view == "pond":
        position, target, scale = (63, 73, -48), (-4, 20, -108), 136
    else:
        position, target, scale = (10.5, 13, -24), (10.5, 1.5, 4), 32
    # Orthographic rays must start outside the foreground backdrop geometry.
    position = Vector(target) + (Vector(position) - Vector(target)) * 2
    camera.location = convert @ position
    focus = convert @ Vector(target)
    camera.rotation_euler = (focus - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = scale
    camera.data.clip_end = 3000
    scene.camera = camera
    args.output.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(args.output.resolve())
    bpy.ops.render.render(write_still=True)
    print(f"Offline geometry preview saved: {args.output}")


if __name__ == "__main__":
    main()
