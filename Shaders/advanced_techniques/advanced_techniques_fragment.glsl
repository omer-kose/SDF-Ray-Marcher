#version 410 core

// HG_SDF BEGINS
////////////////////////////////////////////////////////////////
//
//                           HG_SDF
//
//     GLSL LIBRARY FOR BUILDING SIGNED DISTANCE BOUNDS
//
//     version 2021-07-28
//
//     Check https://mercury.sexy/hg_sdf for updates
//     and usage examples. Send feedback to spheretracing@mercury.sexy.
//
//     Brought to you by MERCURY https://mercury.sexy/
//
//
//
// Released dual-licensed under
//   Creative Commons Attribution-NonCommercial (CC BY-NC)
// or
//   MIT License
// at your choice.
//
// SPDX-License-Identifier: MIT OR CC-BY-NC-4.0
//
// /////
//
// CC-BY-NC-4.0
// https://creativecommons.org/licenses/by-nc/4.0/legalcode
// https://creativecommons.org/licenses/by-nc/4.0/
//
// /////
//
// MIT License
//
// Copyright (c) 2011-2021 Mercury Demogroup
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// /////
//
////////////////////////////////////////////////////////////////
//
// How to use this:
//
// 1. Build some system to #include glsl files in each other.
//   Include this one at the very start. Or just paste everywhere.
// 2. Build a sphere tracer. See those papers:
//   * "Sphere Tracing" https://link.springer.com/article/10.1007%2Fs003710050084
//   * "Enhanced Sphere Tracing" http://diglib.eg.org/handle/10.2312/stag.20141233.001-008
//   * "Improved Ray Casting of Procedural Distance Bounds" https://www.bibsonomy.org/bibtex/258e85442234c3ace18ba4d89de94e57d
//   The Raymnarching Toolbox Thread on pouet can be helpful as well
//   http://www.pouet.net/topic.php?which=7931&page=1
//   and contains links to many more resources.
// 3. Use the tools in this library to build your distance bound f().
// 4. ???
// 5. Win a compo.
//
// (6. Buy us a beer or a good vodka or something, if you like.)
//
////////////////////////////////////////////////////////////////
//
// Table of Contents:
//
// * Helper functions and macros
// * Collection of some primitive objects
// * Domain Manipulation operators
// * Object combination operators
//
////////////////////////////////////////////////////////////////
//
// Why use this?
//
// The point of this lib is that everything is structured according
// to patterns that we ended up using when building geometry.
// It makes it more easy to write code that is reusable and that somebody
// else can actually understand. Especially code on Shadertoy (which seems
// to be what everybody else is looking at for "inspiration") tends to be
// really ugly. So we were forced to do something about the situation and
// release this lib ;)
//
// Everything in here can probably be done in some better way.
// Please experiment. We'd love some feedback, especially if you
// use it in a scene production.
//
// The main patterns for building geometry this way are:
// * Stay Lipschitz continuous. That means: don't have any distance
//   gradient larger than 1. Try to be as close to 1 as possible -
//   Distances are euclidean distances, don't fudge around.
//   Underestimating distances will happen. That's why calling
//   it a "distance bound" is more correct. Don't ever multiply
//   distances by some value to "fix" a Lipschitz continuity
//   violation. The invariant is: each fSomething() function returns
//   a correct distance bound.
// * Use very few primitives and combine them as building blocks
//   using combine opertors that preserve the invariant.
// * Multiply objects by repeating the domain (space).
//   If you are using a loop inside your distance function, you are
//   probably doing it wrong (or you are building boring fractals).
// * At right-angle intersections between objects, build a new local
//   coordinate system from the two distances to combine them in
//   interesting ways.
// * As usual, there are always times when it is best to not follow
//   specific patterns.
//
////////////////////////////////////////////////////////////////
//
// FAQ
//
// Q: Why is there no sphere tracing code in this lib?
// A: Because our system is way too complex and always changing.
//    This is the constant part. Also we'd like everyone to
//    explore for themselves.
//
// Q: This does not work when I paste it into Shadertoy!!!!
// A: Yes. It is GLSL, not GLSL ES. We like real OpenGL
//    because it has way more features and is more likely
//    to work compared to browser-based WebGL. We recommend
//    you consider using OpenGL for your productions. Most
//    of this can be ported easily though.
//
// Q: How do I material?
// A: We recommend something like this:
//    Write a material ID, the distance and the local coordinate
//    p into some global variables whenever an object's distance is
//    smaller than the stored distance. Then, at the end, evaluate
//    the material to get color, roughness, etc., and do the shading.
//
// Q: I found an error. Or I made some function that would fit in
//    in this lib. Or I have some suggestion.
// A: Awesome! Drop us a mail at spheretracing@mercury.sexy.
//
// Q: Why is this not on github?
// A: Because we were too lazy. If we get bugged about it enough,
//    we'll do it.
//
// Q: Your license sucks for me.
// A: Oh. What should we change it to?
//
// Q: I have trouble understanding what is going on with my distances.
// A: Some visualization of the distance field helps. Try drawing a
//    plane that you can sweep through your scene with some color
//    representation of the distance field at each point and/or iso
//    lines at regular intervals. Visualizing the length of the
//    gradient (or better: how much it deviates from being equal to 1)
//    is immensely helpful for understanding which parts of the
//    distance field are broken.
//
////////////////////////////////////////////////////////////////






////////////////////////////////////////////////////////////////
//
//             HELPER FUNCTIONS/MACROS
//
////////////////////////////////////////////////////////////////

#define PI 3.14159265
#define TAU (2*PI)
#define PHI (sqrt(5)*0.5 + 0.5)

// Clamp to [0,1] - this operation is free under certain circumstances.
// For further information see
// http://www.humus.name/Articles/Persson_LowLevelThinking.pdf and
// http://www.humus.name/Articles/Persson_LowlevelShaderOptimization.pdf
#define saturate(x) clamp(x, 0, 1)

// Sign function that doesn't return 0
float sgn(float x) {
    return (x<0)?-1:1;
}

vec2 sgn(vec2 v) {
    return vec2((v.x<0)?-1:1, (v.y<0)?-1:1);
}

float square (float x) {
    return x*x;
}

vec2 square (vec2 x) {
    return x*x;
}

vec3 square (vec3 x) {
    return x*x;
}

float lengthSqr(vec3 x) {
    return dot(x, x);
}


// Maximum/minumum elements of a vector
float vmax(vec2 v) {
    return max(v.x, v.y);
}

float vmax(vec3 v) {
    return max(max(v.x, v.y), v.z);
}

float vmax(vec4 v) {
    return max(max(v.x, v.y), max(v.z, v.w));
}

float vmin(vec2 v) {
    return min(v.x, v.y);
}

float vmin(vec3 v) {
    return min(min(v.x, v.y), v.z);
}

float vmin(vec4 v) {
    return min(min(v.x, v.y), min(v.z, v.w));
}




////////////////////////////////////////////////////////////////
//
//             PRIMITIVE DISTANCE FUNCTIONS
//
////////////////////////////////////////////////////////////////
//
// Conventions:
//
// Everything that is a distance function is called fSomething.
// The first argument is always a point in 2 or 3-space called <p>.
// Unless otherwise noted, (if the object has an intrinsic "up"
// side or direction) the y axis is "up" and the object is
// centered at the origin.
//
////////////////////////////////////////////////////////////////

float fSphere(vec3 p, float r) {
    return length(p) - r;
}

// Plane with normal n (n is normalized) at some distance from the origin
float fPlane(vec3 p, vec3 n, float distanceFromOrigin) {
    return dot(p, n) + distanceFromOrigin;
}

// Cheap Box: distance to corners is overestimated
float fBoxCheap(vec3 p, vec3 b) { //cheap box
    return vmax(abs(p) - b);
}

// Box: correct distance to corners
float fBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return length(max(d, vec3(0))) + vmax(min(d, vec3(0)));
}

// Same as above, but in two dimensions (an endless box)
float fBox2Cheap(vec2 p, vec2 b) {
    return vmax(abs(p)-b);
}

float fBox2(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, vec2(0))) + vmax(min(d, vec2(0)));
}


// Endless "corner"
float fCorner (vec2 p) {
    return length(max(p, vec2(0))) + vmax(min(p, vec2(0)));
}

// Blobby ball object. You've probably seen it somewhere. This is not a correct distance bound, beware.
float fBlob(vec3 p) {
    p = abs(p);
    if (p.x < max(p.y, p.z)) p = p.yzx;
    if (p.x < max(p.y, p.z)) p = p.yzx;
    float b = max(max(max(
        dot(p, normalize(vec3(1, 1, 1))),
        dot(p.xz, normalize(vec2(PHI+1, 1)))),
        dot(p.yx, normalize(vec2(1, PHI)))),
        dot(p.xz, normalize(vec2(1, PHI))));
    float l = length(p);
    return l - 1.5 - 0.2 * (1.5 / 2)* cos(min(sqrt(1.01 - b / l)*(PI / 0.25), PI));
}

// Cylinder standing upright on the xz plane
float fCylinder(vec3 p, float r, float height) {
    float d = length(p.xz) - r;
    d = max(d, abs(p.y) - height);
    return d;
}

// Capsule: A Cylinder with round caps on both sides
float fCapsule(vec3 p, float r, float c) {
    return mix(length(p.xz) - r, length(vec3(p.x, abs(p.y) - c, p.z)) - r, step(c, abs(p.y)));
}

// Distance to line segment between <a> and <b>, used for fCapsule() version 2below
float fLineSegment(vec3 p, vec3 a, vec3 b) {
    vec3 ab = b - a;
    float t = saturate(dot(p - a, ab) / dot(ab, ab));
    return length((ab*t + a) - p);
}

// Capsule version 2: between two end points <a> and <b> with radius r
float fCapsule(vec3 p, vec3 a, vec3 b, float r) {
    return fLineSegment(p, a, b) - r;
}

// Torus in the XZ-plane
float fTorus(vec3 p, float smallRadius, float largeRadius) {
    return length(vec2(length(p.xz) - largeRadius, p.y)) - smallRadius;
}

// A circle line. Can also be used to make a torus by subtracting the smaller radius of the torus.
float fCircle(vec3 p, float r) {
    float l = length(p.xz) - r;
    return length(vec2(p.y, l));
}

// A circular disc with no thickness (i.e. a cylinder with no height).
// Subtract some value to make a flat disc with rounded edge.
float fDisc(vec3 p, float r) {
    float l = length(p.xz) - r;
    return l < 0 ? abs(p.y) : length(vec2(p.y, l));
}

// Hexagonal prism, circumcircle variant
float fHexagonCircumcircle(vec3 p, vec2 h) {
    vec3 q = abs(p);
    return max(q.y - h.y, max(q.x*sqrt(3)*0.5 + q.z*0.5, q.z) - h.x);
    //this is mathematically equivalent to this line, but less efficient:
    //return max(q.y - h.y, max(dot(vec2(cos(PI/3), sin(PI/3)), q.zx), q.z) - h.x);
}

// Hexagonal prism, incircle variant
float fHexagonIncircle(vec3 p, vec2 h) {
    return fHexagonCircumcircle(p, vec2(h.x*sqrt(3)*0.5, h.y));
}

// Cone with correct distances to tip and base circle. Y is up, 0 is in the middle of the base.
float fCone(vec3 p, float radius, float height) {
    vec2 q = vec2(length(p.xz), p.y);
    vec2 tip = q - vec2(0, height);
    vec2 mantleDir = normalize(vec2(height, radius));
    float mantle = dot(tip, mantleDir);
    float d = max(mantle, -q.y);
    float projected = dot(tip, vec2(mantleDir.y, -mantleDir.x));
    
    // distance to tip
    if ((q.y > height) && (projected < 0)) {
        d = max(d, length(tip));
    }
    
    // distance to base ring
    if ((q.x > radius) && (projected > length(vec2(height, radius)))) {
        d = max(d, length(q - vec2(radius, 0)));
    }
    return d;
}

//
// "Generalized Distance Functions" by Akleman and Chen.
// see the Paper at https://www.viz.tamu.edu/faculty/ergun/research/implicitmodeling/papers/sm99.pdf
//
// This set of constants is used to construct a large variety of geometric primitives.
// Indices are shifted by 1 compared to the paper because we start counting at Zero.
// Some of those are slow whenever a driver decides to not unroll the loop,
// which seems to happen for fIcosahedron und fTruncatedIcosahedron on nvidia 350.12 at least.
// Specialized implementations can well be faster in all cases.
//

const vec3 GDFVectors[19] = vec3[](
    normalize(vec3(1, 0, 0)),
    normalize(vec3(0, 1, 0)),
    normalize(vec3(0, 0, 1)),

    normalize(vec3(1, 1, 1 )),
    normalize(vec3(-1, 1, 1)),
    normalize(vec3(1, -1, 1)),
    normalize(vec3(1, 1, -1)),

    normalize(vec3(0, 1, PHI+1)),
    normalize(vec3(0, -1, PHI+1)),
    normalize(vec3(PHI+1, 0, 1)),
    normalize(vec3(-PHI-1, 0, 1)),
    normalize(vec3(1, PHI+1, 0)),
    normalize(vec3(-1, PHI+1, 0)),

    normalize(vec3(0, PHI, 1)),
    normalize(vec3(0, -PHI, 1)),
    normalize(vec3(1, 0, PHI)),
    normalize(vec3(-1, 0, PHI)),
    normalize(vec3(PHI, 1, 0)),
    normalize(vec3(-PHI, 1, 0))
);

// Version with variable exponent.
// This is slow and does not produce correct distances, but allows for bulging of objects.
float fGDF(vec3 p, float r, float e, int begin, int end) {
    float d = 0;
    for (int i = begin; i <= end; ++i)
        d += pow(abs(dot(p, GDFVectors[i])), e);
    return pow(d, 1/e) - r;
}

// Version with without exponent, creates objects with sharp edges and flat faces
float fGDF(vec3 p, float r, int begin, int end) {
    float d = 0;
    for (int i = begin; i <= end; ++i)
        d = max(d, abs(dot(p, GDFVectors[i])));
    return d - r;
}

// Primitives follow:

float fOctahedron(vec3 p, float r, float e) {
    return fGDF(p, r, e, 3, 6);
}

float fDodecahedron(vec3 p, float r, float e) {
    return fGDF(p, r, e, 13, 18);
}

float fIcosahedron(vec3 p, float r, float e) {
    return fGDF(p, r, e, 3, 12);
}

float fTruncatedOctahedron(vec3 p, float r, float e) {
    return fGDF(p, r, e, 0, 6);
}

float fTruncatedIcosahedron(vec3 p, float r, float e) {
    return fGDF(p, r, e, 3, 18);
}

float fOctahedron(vec3 p, float r) {
    return fGDF(p, r, 3, 6);
}

float fDodecahedron(vec3 p, float r) {
    return fGDF(p, r, 13, 18);
}

float fIcosahedron(vec3 p, float r) {
    return fGDF(p, r, 3, 12);
}

float fTruncatedOctahedron(vec3 p, float r) {
    return fGDF(p, r, 0, 6);
}

float fTruncatedIcosahedron(vec3 p, float r) {
    return fGDF(p, r, 3, 18);
}


////////////////////////////////////////////////////////////////
//
//                DOMAIN MANIPULATION OPERATORS
//
////////////////////////////////////////////////////////////////
//
// Conventions:
//
// Everything that modifies the domain is named pSomething.
//
// Many operate only on a subset of the three dimensions. For those,
// you must choose the dimensions that you want manipulated
// by supplying e.g. <p.x> or <p.zx>
//
// <inout p> is always the first argument and modified in place.
//
// Many of the operators partition space into cells. An identifier
// or cell index is returned, if possible. This return value is
// intended to be optionally used e.g. as a random seed to change
// parameters of the distance functions inside the cells.
//
// Unless stated otherwise, for cell index 0, <p> is unchanged and cells
// are centered on the origin so objects don't have to be moved to fit.
//
//
////////////////////////////////////////////////////////////////



// Rotate around a coordinate axis (i.e. in a plane perpendicular to that axis) by angle <a>.
// Read like this: R(p.xz, a) rotates "x towards z".
// This is fast if <a> is a compile-time constant and slower (but still practical) if not.
void pR(inout vec2 p, float a) {
    p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

// Shortcut for 45-degrees rotation
void pR45(inout vec2 p) {
    p = (p + vec2(p.y, -p.x))*sqrt(0.5);
}

// Repeat space along one axis. Use like this to repeat along the x axis:
// <float cell = pMod1(p.x,5);> - using the return value is optional.
float pMod1(inout float p, float size) {
    float halfsize = size*0.5;
    float c = floor((p + halfsize)/size);
    p = mod(p + halfsize, size) - halfsize;
    return c;
}

// Same, but mirror every second cell so they match at the boundaries
float pModMirror1(inout float p, float size) {
    float halfsize = size*0.5;
    float c = floor((p + halfsize)/size);
    p = mod(p + halfsize,size) - halfsize;
    p *= mod(c, 2.0)*2 - 1;
    return c;
}

// Repeat the domain only in positive direction. Everything in the negative half-space is unchanged.
float pModSingle1(inout float p, float size) {
    float halfsize = size*0.5;
    float c = floor((p + halfsize)/size);
    if (p >= 0)
        p = mod(p + halfsize, size) - halfsize;
    return c;
}

// Repeat only a few times: from indices <start> to <stop> (similar to above, but more flexible)
float pModInterval1(inout float p, float size, float start, float stop) {
    float halfsize = size*0.5;
    float c = floor((p + halfsize)/size);
    p = mod(p+halfsize, size) - halfsize;
    if (c > stop) { //yes, this might not be the best thing numerically.
        p += size*(c - stop);
        c = stop;
    }
    if (c <start) {
        p += size*(c - start);
        c = start;
    }
    return c;
}


// Repeat around the origin by a fixed angle.
// For easier use, num of repetitions is use to specify the angle.
float pModPolar(inout vec2 p, float repetitions) {
    float angle = 2*PI/repetitions;
    float a = atan(p.y, p.x) + angle/2.;
    float r = length(p);
    float c = floor(a/angle);
    a = mod(a,angle) - angle/2.;
    p = vec2(cos(a), sin(a))*r;
    // For an odd number of repetitions, fix cell index of the cell in -x direction
    // (cell index would be e.g. -5 and 5 in the two halves of the cell):
    if (abs(c) >= (repetitions/2)) c = abs(c);
    return c;
}

// Repeat in two dimensions
vec2 pMod2(inout vec2 p, vec2 size) {
    vec2 c = floor((p + size*0.5)/size);
    p = mod(p + size*0.5,size) - size*0.5;
    return c;
}

// Same, but mirror every second cell so all boundaries match
vec2 pModMirror2(inout vec2 p, vec2 size) {
    vec2 halfsize = size*0.5;
    vec2 c = floor((p + halfsize)/size);
    p = mod(p + halfsize, size) - halfsize;
    p *= mod(c,vec2(2))*2 - vec2(1);
    return c;
}

// Same, but mirror every second cell at the diagonal as well
vec2 pModGrid2(inout vec2 p, vec2 size) {
    vec2 c = floor((p + size*0.5)/size);
    p = mod(p + size*0.5, size) - size*0.5;
    p *= mod(c,vec2(2))*2 - vec2(1);
    p -= size/2;
    if (p.x > p.y) p.xy = p.yx;
    return floor(c/2);
}

// Repeat in three dimensions
vec3 pMod3(inout vec3 p, vec3 size) {
    vec3 c = floor((p + size*0.5)/size);
    p = mod(p + size*0.5, size) - size*0.5;
    return c;
}

// Mirror at an axis-aligned plane which is at a specified distance <dist> from the origin.
float pMirror (inout float p, float dist) {
    float s = sgn(p);
    p = abs(p)-dist;
    return s;
}

// Mirror in both dimensions and at the diagonal, yielding one eighth of the space.
// translate by dist before mirroring.
vec2 pMirrorOctant (inout vec2 p, vec2 dist) {
    vec2 s = sgn(p);
    pMirror(p.x, dist.x);
    pMirror(p.y, dist.y);
    if (p.y > p.x)
        p.xy = p.yx;
    return s;
}

// Reflect space at a plane
float pReflect(inout vec3 p, vec3 planeNormal, float offset) {
    float t = dot(p, planeNormal)+offset;
    if (t < 0) {
        p = p - (2*t)*planeNormal;
    }
    return sgn(t);
}


////////////////////////////////////////////////////////////////
//
//             OBJECT COMBINATION OPERATORS
//
////////////////////////////////////////////////////////////////
//
// We usually need the following boolean operators to combine two objects:
// Union: OR(a,b)
// Intersection: AND(a,b)
// Difference: AND(a,!b)
// (a and b being the distances to the objects).
//
// The trivial implementations are min(a,b) for union, max(a,b) for intersection
// and max(a,-b) for difference. To combine objects in more interesting ways to
// produce rounded edges, chamfers, stairs, etc. instead of plain sharp edges we
// can use combination operators. It is common to use some kind of "smooth minimum"
// instead of min(), but we don't like that because it does not preserve Lipschitz
// continuity in many cases.
//
// Naming convention: since they return a distance, they are called fOpSomething.
// The different flavours usually implement all the boolean operators above
// and are called fOpUnionRound, fOpIntersectionRound, etc.
//
// The basic idea: Assume the object surfaces intersect at a right angle. The two
// distances <a> and <b> constitute a new local two-dimensional coordinate system
// with the actual intersection as the origin. In this coordinate system, we can
// evaluate any 2D distance function we want in order to shape the edge.
//
// The operators below are just those that we found useful or interesting and should
// be seen as examples. There are infinitely more possible operators.
//
// They are designed to actually produce correct distances or distance bounds, unlike
// popular "smooth minimum" operators, on the condition that the gradients of the two
// SDFs are at right angles. When they are off by more than 30 degrees or so, the
// Lipschitz condition will no longer hold (i.e. you might get artifacts). The worst
// case is parallel surfaces that are close to each other.
//
// Most have a float argument <r> to specify the radius of the feature they represent.
// This should be much smaller than the object size.
//
// Some of them have checks like "if ((-a < r) && (-b < r))" that restrict
// their influence (and computation cost) to a certain area. You might
// want to lift that restriction or enforce it. We have left it as comments
// in some cases.
//
// usage example:
//
// float fTwoBoxes(vec3 p) {
//   float box0 = fBox(p, vec3(1));
//   float box1 = fBox(p-vec3(1), vec3(1));
//   return fOpUnionChamfer(box0, box1, 0.2);
// }
//
////////////////////////////////////////////////////////////////


// The "Chamfer" flavour makes a 45-degree chamfered edge (the diagonal of a square of size <r>):
float fOpUnionChamfer(float a, float b, float r) {
    return min(min(a, b), (a - r + b)*sqrt(0.5));
}

// Intersection has to deal with what is normally the inside of the resulting object
// when using union, which we normally don't care about too much. Thus, intersection
// implementations sometimes differ from union implementations.
float fOpIntersectionChamfer(float a, float b, float r) {
    return max(max(a, b), (a + r + b)*sqrt(0.5));
}

// Difference can be built from Intersection or Union:
float fOpDifferenceChamfer (float a, float b, float r) {
    return fOpIntersectionChamfer(a, -b, r);
}

// The "Round" variant uses a quarter-circle to join the two objects smoothly:
float fOpUnionRound(float a, float b, float r) {
    vec2 u = max(vec2(r - a,r - b), vec2(0));
    return max(r, min (a, b)) - length(u);
}

float fOpIntersectionRound(float a, float b, float r) {
    vec2 u = max(vec2(r + a,r + b), vec2(0));
    return min(-r, max (a, b)) + length(u);
}

float fOpDifferenceRound (float a, float b, float r) {
    return fOpIntersectionRound(a, -b, r);
}


// The "Columns" flavour makes n-1 circular columns at a 45 degree angle:
float fOpUnionColumns(float a, float b, float r, float n) {
    if ((a < r) && (b < r)) {
        vec2 p = vec2(a, b);
        float columnradius = r*sqrt(2)/((n-1)*2+sqrt(2));
        pR45(p);
        p.x -= sqrt(2)/2*r;
        p.x += columnradius*sqrt(2);
        if (mod(n,2) == 1) {
            p.y += columnradius;
        }
        // At this point, we have turned 45 degrees and moved at a point on the
        // diagonal that we want to place the columns on.
        // Now, repeat the domain along this direction and place a circle.
        pMod1(p.y, columnradius*2);
        float result = length(p) - columnradius;
        result = min(result, p.x);
        result = min(result, a);
        return min(result, b);
    } else {
        return min(a, b);
    }
}

float fOpDifferenceColumns(float a, float b, float r, float n) {
    a = -a;
    float m = min(a, b);
    //avoid the expensive computation where not needed (produces discontinuity though)
    if ((a < r) && (b < r)) {
        vec2 p = vec2(a, b);
        float columnradius = r*sqrt(2)/n/2.0;
        columnradius = r*sqrt(2)/((n-1)*2+sqrt(2));

        pR45(p);
        p.y += columnradius;
        p.x -= sqrt(2)/2*r;
        p.x += -columnradius*sqrt(2)/2;

        if (mod(n,2) == 1) {
            p.y += columnradius;
        }
        pMod1(p.y,columnradius*2);

        float result = -length(p) + columnradius;
        result = max(result, p.x);
        result = min(result, a);
        return -min(result, b);
    } else {
        return -m;
    }
}

float fOpIntersectionColumns(float a, float b, float r, float n) {
    return fOpDifferenceColumns(a,-b,r, n);
}

// The "Stairs" flavour produces n-1 steps of a staircase:
// much less stupid version by paniq
float fOpUnionStairs(float a, float b, float r, float n) {
    float s = r/n;
    float u = b-r;
    return min(min(a,b), 0.5 * (u + a + abs ((mod (u - a + s, 2 * s)) - s)));
}

// We can just call Union since stairs are symmetric.
float fOpIntersectionStairs(float a, float b, float r, float n) {
    return -fOpUnionStairs(-a, -b, r, n);
}

float fOpDifferenceStairs(float a, float b, float r, float n) {
    return -fOpUnionStairs(-a, b, r, n);
}


// Similar to fOpUnionRound, but more lipschitz-y at acute angles
// (and less so at 90 degrees). Useful when fudging around too much
// by MediaMolecule, from Alex Evans' siggraph slides
float fOpUnionSoft(float a, float b, float r) {
    float e = max(r - abs(a - b), 0);
    return min(a, b) - e*e*0.25/r;
}


// produces a cylindical pipe that runs along the intersection.
// No objects remain, only the pipe. This is not a boolean operator.
float fOpPipe(float a, float b, float r) {
    return length(vec2(a, b)) - r;
}

// first object gets a v-shaped engraving where it intersect the second
float fOpEngrave(float a, float b, float r) {
    return max(a, (a + r - abs(b))*sqrt(0.5));
}

// first object gets a capenter-style groove cut out
float fOpGroove(float a, float b, float ra, float rb) {
    return max(a, min(a + ra, rb - abs(b)));
}

// first object gets a capenter-style tongue attached
float fOpTongue(float a, float b, float ra, float rb) {
    return min(a, max(a - ra, abs(b) - rb));
}


// HG_SDF ENDS


in vec2 uv;

out vec4 FragColor;

//UNIFORMS
uniform vec2 resolution;
uniform vec3 camera_pos;
uniform vec3 front;
uniform vec3 right;
uniform vec3 up;
uniform float time;
//Textures
uniform sampler2D texture0; // floor
uniform sampler2D texture1; // walls
uniform sampler2D texture2; // roof
uniform sampler2D texture3; // pedestal
uniform sampler2D texture4; // sphere
uniform sampler2D texture5; //roof bump


const int MAX_STEPS = 256;
const float MAX_DIST = 500;
const float EPSILON = 0.001;

float cubeSize = 6.0;
float cubeScale = 1.0 / cubeSize;
float roofScale = 0.15;
float pedestalScale = 0.3;
float floorScale = 0.15;
float sphereScale = 0.2;
float wallScale = 0.12;

float roofBumpFactor = 0.31;
float sphereBumpFactor = 0.21;
float wallBumpFactor = 0.06;


/*
    Triplanar texture mapping.
 
    The method accumulates the texture colors in xy-xz-yz planes seperately by multiplying
    the texture color in the corresponding plane with its normal.
*/
vec3 triplanar(sampler2D tex, vec3 p, vec3 normal)
{
    normal = abs(normal); //Revert the negative normals to get a texture on back faces as well
    //When triplanar mapping is used for spherical objects the textures gets too stretched
    //Following trick cures this
    normal = pow(normal, vec3(5.0));
    normal /= normal.x + normal.y + normal.z;
    return (texture(tex, p.xy * 0.5 + 0.5) * normal.z +
            texture(tex, p.xz * 0.5 + 0.5) * normal.y +
            texture(tex, p.yz * 0.5 + 0.5) * normal.x).rgb;
}


float bump_mapping(sampler2D tex, vec3 p, vec3 n, float dist, float factor, float scale)
{
    float bump = 0.0;
    if(dist < 0.1)
    {
        bump += factor * triplanar(tex, (p * scale), n).r;
    }
    
    return bump;
}

/*
    Information is conveyed as a vec2. (Let us call them objects)
    vec2 object;
    object.x: sdf value
    object.y: material ID (id being float will be no problem as we will cast it to int while fetching the material)
                          (moreover, it is guaranteed that a material is mapped to one id)
*/


/*
    hg_sdf utility variants which also includes the id information
*/

vec2 fOpUnionID(vec2 res1, vec2 res2)
{
    return (res1.x < res2.x) ? res1 : res2;
}

//A-B == A intersect (-B)
vec2 fOpDifferenceID(vec2 res1, vec2 res2)
{
    return (res1.x > -res2.x) ? res1 : vec2(-res2.x, res2.y);
}

vec2 fOpDifferenceColumnsID(vec2 res1, vec2 res2, float r, float n)
{
    float dist = fOpDifferenceColumns(res1.x, res2.x, r, n);
    return (res1.x > -res2.x) ? vec2(dist, res1.y) : vec2(dist, res2.y);
}

vec2 fOpUnionStairsID(vec2 res1, vec2 res2, float r, float n)
{
    float dist = fOpUnionStairs(res1.x, res2.x, r, n);
    return (res1.x < res2.x) ? vec2(dist, res1.y) : vec2(dist, res2.y);
}

vec2 fOpUnionChamferID(vec2 res1, vec2 res2, float r)
{
    float dist = fOpUnionChamfer(res1.x, res2.x, r);
    return (res1.x < res2.x) ? vec2(dist, res1.y) : vec2(dist, res2.y);
}

float fDisplace(vec3 p)
{
    pR(p.yz, sin(2.0 * time));
    return (sin(p.x + 4.0 * time) * sin(p.y + sin(2.0 * time)) * sin(p.z + 6.0 * time));
}


vec2 getPedestal(vec3 p)
{
    float ID = 9.0;
    float resDist;
    // box 1
    p.y += 13.8;
    float box1 = fBoxCheap(p, vec3(8, 0.4, 8));
    // box 2
    p.y -= 6.4;
    float box2 = fBoxCheap(p, vec3(7, 6, 7));
    // box 3
    pMirrorOctant(p.zx, vec2(7.5, 7.5));
    float box3 = fBoxCheap(p, vec3(5, 4, 1));
    // res
    resDist = box1;
    resDist = min(resDist, box2);
    resDist = fOpDifferenceColumns(resDist, box3, 1.9, 10.0);
    return vec2(resDist, ID);
}

void translateSphere(inout vec3 p)
{
    p.y -= 4.4;
}

void rotateSphere(inout vec3 p)
{
    pR(p.xz, 0.3 * time);
}

void translateCube(inout vec3 p)
{
    p.y -= 2.5;
    p.xz += 1.5;
}

void rotateCube(inout vec3 p)
{
    pR(p.yz, PI / 4);
    pR(p.xz, time);
}

/*
    Given the point p returns the closest object
*/
vec2 closest_object(vec3 p)
{
    vec3 tmp, op = p;
    // plane
    float planeDist = fPlane(p, vec3(0, 1, 0), 14.0);
    float planeID = 6.0;
    vec2 plane = vec2(planeDist, planeID);

    // cube
//    vec3 pb = p;
//    translateCube(pb);
//    rotateCube(pb);
//    float cubeDist = fBoxCheap(pb, vec3(cubeSize));
//    float cubeID = 5.0;
//    vec2 cube = vec2(cubeDist, cubeID);

    // pedestal
    
    vec2 pedestal = getPedestal(p);
    // sphere
    vec3 ps = p;
    translateSphere(ps);
    rotateSphere(ps);
    float sphereDist = fSphere(ps, 6.0);
    sphereDist += bump_mapping(texture4, ps, ps + sphereBumpFactor,
                             sphereDist, sphereBumpFactor, sphereScale);
    sphereDist += sphereBumpFactor;
    float sphereID = 10.0;
    vec2 sphere = vec2(sphereDist, sphereID);

    // manipulation operators
    pMirrorOctant(p.xz, vec2(50, 50));
    p.x = -abs(p.x) + 20;
    pMod1(p.z, 15);

    // roof
    vec3 pr = p;
    pr.y -= 15.7;
    pR(pr.xy, 0.6);
    pr.x -= 18.0;
    float roofDist = fBox2Cheap(pr.xy, vec2(20, 0.5));
    roofDist -= bump_mapping(texture5, p, p - roofBumpFactor, roofDist, roofBumpFactor, roofScale);
    roofDist += roofBumpFactor;
    float roofID = 8.0;
    vec2 roof = vec2(roofDist, roofID);

    // box
    float boxDist = fBoxCheap(p, vec3(3,9,4));
    float boxID = 7.0;
    vec2 box = vec2(boxDist, boxID);

    // cylinder
    vec3 pc = p;
    pc.y -= 9.0;
    float cylinderDist = fCylinder(pc.yxz, 4, 3);
    float cylinderID = 7.0;
    vec2 cylinder = vec2(cylinderDist, cylinderID);

    // wall
    float wallDist = fBox2Cheap(p.xy, vec2(1, 15));
    wallDist -= bump_mapping(texture1, op, op + wallBumpFactor, wallDist, wallBumpFactor, wallScale);
    wallDist += wallBumpFactor;
    float wallID = 7.0;
    vec2 wall = vec2(wallDist, wallID);

    // result
    vec2 res;
    res = fOpUnionID(box, cylinder);
    res = fOpDifferenceColumnsID(wall, res, 0.6, 3.0);
    res = fOpUnionChamferID(res, roof, 0.6);
    res = fOpUnionStairsID(res, plane, 4.0, 5.0);
    res = fOpUnionID(res, sphere);
    res = fOpUnionID(res, pedestal);
//    res = fOpUnionID(res, cube);
    res = res;
    return res;
}

/*
    March from ro towards rd.
    Returns the object hit.
 
    Note: If there is no hit object.x > MAX_DIST
*/
vec2 ray_march(vec3 ro, vec3 rd)
{
    vec2 object = vec2(0.0); //The final object the ray lands on
    vec2 hit = vec2(0.0); //The current hit
    vec3 p = vec3(0.0);
    for(int i = 0; i < MAX_STEPS; ++i)
    {
        p = ro + object.x * rd;
        hit = closest_object(p);
        object.x += hit.x;
        object.y = hit.y;
        if(abs(hit.x) < EPSILON || object.x > MAX_DIST)
        {
            break;
        }
    }
    
    return object;
}


vec3 get_normal(vec3 p)
{
    return normalize(vec3(
                          closest_object(vec3(p.x + EPSILON, p.y, p.z)).x - closest_object(vec3(p.x - EPSILON, p.y, p.z)).x,
                          closest_object(vec3(p.x, p.y + EPSILON, p.z)).x - closest_object(vec3(p.x, p.y - EPSILON, p.z)).x,
                          closest_object(vec3(p.x, p.y, p.z  + EPSILON)).x - closest_object(vec3(p.x, p.y, p.z - EPSILON)).x));
}


float get_soft_shadow(vec3 p, vec3 light_pos)
{
    float res = 1.0;
    float dist = 0.01;
    float light_size = 0.03;
    for(int i = 0; i < MAX_STEPS; ++i)
    {
        float hit = closest_object(p + light_pos * dist).x;
        res = min(res, hit / (dist * light_size));
        dist += hit;
        if(hit < 0.0001 || dist > 60.0)
        {
            break;
        }
    }
    
    return clamp(res, 0.0, 1.0);
}

float get_ambient_occlusion(vec3 p, vec3 normal)
{
    float occ = 0.0;
    float weight = 1.0;
    for(int i = 0; i < 8; ++i)
    {
        float len = 0.01 + 0.02 * float(i * i);
        float dist = closest_object(p + normal * len).x;
        occ += (len - dist) * weight;
        weight *= 0.85;
    }
    
    return 1.0 - clamp(0.6 * occ, 0.0, 1.0);
}

vec3 get_material(vec3 p, float id, vec3 normal)
{
    vec3 m;
    switch (int(id))
    {
        case 1:
            m = vec3(0.9, 0.0, 0.0); break;

        case 2:
            m = vec3(0.2 + 0.4 * mod(floor(p.x) + floor(p.z), 2.0)); break;

        case 3:
            m = vec3(0.7, 0.8, 0.9); break;

        case 4:
            vec2 i = step(fract(0.5 * p.xz), vec2(1.0 / 10.0));
            m = ((1.0 - i.x) * (1.0 - i.y)) * vec3(0.37, 0.12, 0.0);
            break;

        // cube
        case 5:
//          translateCube(p);
//          rotateCube(p);
//          rotateCube(normal);
            m = triplanar(texture0, p * cubeScale, normal);
            break;

        // floor
        case 6:
            m = triplanar(texture0, p * floorScale, normal);
            break;

        // walls
        case 7:
            m = triplanar(texture1, p * wallScale, normal);
            break;

        // roof
        case 8:
            m = triplanar(texture2, p * roofScale, normal);
            break;

        // pedestal
        case 9:
            m = triplanar(texture3, p * pedestalScale, normal);
            break;

        // sphere
        case 10:
            translateSphere(p);
            rotateSphere(p);
            rotateSphere(normal);
            m = triplanar(texture4, p * sphereScale, normal);
            break;

        // roof bump
        case 11:
            m = triplanar(texture5, p * roofScale, normal);
            break;

        default:
            m = vec3(0.4);
            break;
    }
    return m;
}


vec3 get_light(vec3 p, vec3 rd, float id)
{
    vec3 light_pos = vec3(20.0, 40.0, 30.0);
    vec3 L = normalize(light_pos - p);
    vec3 N = get_normal(p);
    vec3 V = -rd;
    vec3 R = reflect(-L, N);
    
    vec3 color = get_material(p, id, N);
   
    vec3 spec_color = vec3(0.5);
    vec3 specular = spec_color * pow(clamp(dot(R, V), 0.0, 1.0), 10.0);
    vec3 diffuse = color * clamp(dot(L, N), 0.0, 1.0);
    vec3 ambient = color * 0.05;
    vec3 fresnel = 0.25 * color * pow(1.0 + dot(rd, N), 3.0);
    
    //Shadows
    float shadow = get_soft_shadow(p + N * 0.02, normalize(light_pos));
    //Ambient Occlusion
    float occ = get_ambient_occlusion(p, N);
    //The light that is reflected back from the illuminated objects
    vec3 reflected_back = 0.05 * color * clamp(dot(N, L), 0.0, 1.0);
   
    //Shadow affects diffuse and specular
    //Occlusion affects specular ambient and fresnel
    return shadow * (diffuse + specular * occ) + (reflected_back + ambient + fresnel) * occ;
}


vec3 render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);
    vec2 object = ray_march(ro, rd);
    
    vec3 background = vec3(0.5, 0.8, 0.9);
    
    //If there is a hit
    if(object.x < MAX_DIST)
    {
        vec3 p = ro + object.x * rd;
        col += get_light(p, rd, object.y);
        //Fog
        col = mix(col, background, 1.0 - exp(-0.00002 * object.x * object.x));
    }
    else
    {
        col += background - max(0.9 * rd.y, 0.0);
    }
   
    return col;
}

//Utility for AA
vec3 ro_with_offset(mat3 lookAt, vec2 aspect_ratio, vec2 offset)
{
    vec2 p = (resolution * uv + offset) / resolution;
    return lookAt * normalize(vec3(aspect_ratio * (p - 0.5), -1.0));
}

//SSAA: Super Sampling Anti Aliasing
vec3 renderAAx4(vec3 ro, mat3 lookAt, vec2 aspect_ratio)
{
    vec4 o = vec4(0.125, -0.125, 0.375, -0.375);
    vec3 col_AA = render(ro, ro_with_offset(lookAt, aspect_ratio, o.xz))
                + render(ro, ro_with_offset(lookAt, aspect_ratio, o.yw))
                + render(ro, ro_with_offset(lookAt, aspect_ratio, o.wx))
                + render(ro, ro_with_offset(lookAt, aspect_ratio, o.zy));
    
    return col_AA / 4.0;
}

void main()
{
    vec2 aspect_ratio = vec2(resolution.x / resolution.y, 1.0);
    vec3 ro = camera_pos;
    mat3 lookAt = mat3(right, up, -front);
    vec3 rd = lookAt * normalize(vec3(aspect_ratio * (uv - 0.5), -1.0));
    
    
    vec3 col = render(ro, rd);
    //vec3 col = renderAAx4(ro, lookAt, aspect_ratio);
    //Gamma Correction
    col = pow(col, vec3(0.4545));
    FragColor = vec4(col, 1.0);
}
