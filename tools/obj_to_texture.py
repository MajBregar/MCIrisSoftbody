#!/usr/bin/env python3
"""Bake a triangulated OBJ into raw vertex textures.

Usage: python tools/obj_to_texture.py assets/sphere.obj
"""

import argparse
import math
from pathlib import Path
from bake_indexed import bake

def convert(path, root):
    
    vertices, faces = [], []
    
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        fields = line.split("#", 1)[0].split()
        
        if not fields:
            continue
        
        if fields[0] == "v":
            if len(fields) < 4:
                raise ValueError(f"Line {line_number}: vertex needs x y z")
            
            position = tuple(float(component) for component in fields[1:4])
            
            if not all(math.isfinite(component) for component in position):
                raise ValueError(f"Line {line_number}: non-finite coordinate")
            
            vertices.append(position)
            
        elif fields[0] == "f":
            if len(fields) != 4:
                raise ValueError(f"Line {line_number}: triangulate faces in your model editor first")
            
            face = []
            for field in fields[1:]:
                index = int(field.split("/")[0])
                
                if index == 0:
                    raise ValueError(f"Line {line_number}: OBJ indices cannot be zero")
                
                index = index - 1 if index > 0 else len(vertices) + index
                
                if not 0 <= index < len(vertices):
                    raise ValueError(f"Line {line_number}: invalid vertex index")
                
                face.append(index)
                
            faces.append(tuple(face))
            
    if not vertices or not faces:
        raise ValueError("No triangle mesh found")
    
    center = tuple((min(position[axis] for position in vertices) + max(position[axis] for position in vertices)) / 2 for axis in range(3))
    centered_vertices = [ tuple(position[axis] - center[axis] for axis in range(3)) for position in vertices]
    radius = max( math.sqrt(sum(component * component for component in position)) for position in centered_vertices)
    
    if radius <= 1e-12:
        raise ValueError("Mesh has zero size")
    
    normalized_vertices = [ tuple(component / radius for component in position) for position in centered_vertices]
    bake(normalized_vertices, faces, root)
    
    print(f"Baked {len(vertices)} unique particles / {len(faces)} triangles. Original center={center}, radius={radius:g}.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("obj", type=Path)
    arguments = parser.parse_args()
    convert(arguments.obj, Path(__file__).resolve().parents[1])
