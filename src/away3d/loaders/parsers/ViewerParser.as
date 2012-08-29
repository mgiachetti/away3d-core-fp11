package away3d.loaders.parsers
{
	import away3d.arcane;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.entities.Mesh;
	import away3d.library.assets.IAsset;
	import away3d.loaders.misc.ResourceDependency;
	import away3d.materials.ColorMaterial;
	import away3d.materials.TextureMaterial;
	import away3d.materials.lightpickers.LightPickerBase;
	import away3d.materials.lightpickers.StaticLightPicker;
	import away3d.materials.methods.EnvMapAmbientMethod;
	import away3d.materials.methods.EnvMapMethod;
	import away3d.materials.methods.FilteredShadowMapMethod;
	import away3d.materials.methods.SoftShadowMapMethod;
	import away3d.materials.utils.DefaultMaterialManager;
	import away3d.textures.BitmapTexture;
	import away3d.textures.Texture2DBase;
	
	import com.mgsoft.mg3dengine.FilePath;
	import com.mgsoft.mg3dengine.MG3DGlobals;
	
	import flash.geom.Matrix3D;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	
	import flashx.textLayout.factory.TruncationOptions;
	

	use namespace arcane;
	
	/**
	 * OBJParser provides a parser for the OBJ data type.
	 */
	public class ViewerParser extends ParserBase
	{
		private var _textData:String;
		
		private var _charIndex:int;
		private var _oldIndex:int;
		private var _stringLength:uint;
		
		//private var _currentObject : ObjectGroup;
		//private var _currentGroup : Group;
		//private var _currentMaterialGroup : MaterialGroup;
		//private var _objects : Vector.<ObjectGroup>;
		private var _materialIDs : Vector.<String>;
		//private var _materialLoaded : Vector.<LoadedMaterial>;
		//private var _materialSpecularData : Vector.<SpecularData>;
		private var _meshes : Vector.<Mesh>;
		private var _lastMtlID:String;
		private var _objectIndex : uint;
		private var _realIndices : Array;
		private var _vertexIndex : uint;

		// TODO: not used
		// private var _idCount : uint;
		private var _activeMaterialID:String = "";
		
		private var _indices : Vector.<uint>;
		private var _vertices : Vector.<Number>;
		private var _vertexNormals : Vector.<Number>;
		private var _uvs : Vector.<Number>;
		private var _startedParsing : Boolean;
		private var _parsedTextures:Boolean;
		private var _parsedMeshes:Boolean;
		private var _parsedFaces:Boolean;
		private var _cant_texturas:int;
		private var _cant_meshes:int;
		private var _cant_faces:int;
		private var texturasID:Vector.<String> = new Vector.<String>();
		private var texturaXMesh:Vector.<int> = new Vector.<int>();
		private var meshesID:Vector.<String> = new Vector.<String>();
		private var meshXMesh:Vector.<int> = new Vector.<int>();
		private var worldmatXMesh:Vector.<Matrix3D> = new Vector.<Matrix3D>();
		private var layersXMesh:Vector.<Vector.<int>> = new Vector.<Vector.<int>>();
		private var texturas: Vector.<Texture2DBase> = new Vector.<Texture2DBase>();
		
		/**
		 * Loads a Viewer.dat Lepton File.
		 */
		public function ViewerParser()
		{
			super(ParserDataFormat.PLAIN_TEXT);			
		}
		
		
		/**
		 * Indicates whether or not a given file extension is supported by the parser.
		 * @param extension The file extension of a potential file to be parsed.
		 * @return Whether or not the given file type is supported.
		 */
		public static function supportsType(extension : String) : Boolean
		{
			extension = extension.toLowerCase();
			return extension == "dat";
		}
		
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependency(resourceDependency:ResourceDependency):void
		{
			var extension :String = FilePath.GetExtension(resourceDependency.id).toLowerCase(); 
			if (extension == '.msh' || extension == '.y' || extension == '.x') {
				if (resourceDependency.assets.length != 1)
					return;
				
				var mesh : Mesh = resourceDependency.assets[0] as Mesh;
				
				var idMesh:int = meshesID.indexOf(resourceDependency.id);
				
				if(idMesh == -1 || mesh == null)
					return;
				
				
				for (var i:int = 0; i < meshXMesh.length; i++) 
				{
					if(meshXMesh[i] == idMesh)
					{
						_meshes[i].geometry = mesh.geometry;
						_meshes[i].material = mesh.material;
						_meshes[i].bounds = mesh.bounds.clone();
						_meshes[i].pivotPoint = mesh.pivotPoint.clone();
						_meshes[i].partition = mesh.partition;
						_meshes[i].transform = worldmatXMesh[i];
						_meshes[i].showBounds = false;
						
						for (var j:int = 0; j < _meshes[i].subMeshes.length; j++) 
						{
							var layer_tex : int = layersXMesh[i][_meshes[i].geometry.subGeometries[j].nroLayer];
							if(layer_tex == -1)
							{
								_meshes[i].subMeshes[j].material = mesh.subMeshes[j].material;
								_meshes[i].subMeshes[j].material.bothSides = true;
							}
							else
							{
								//tiene una textura propia el layer
								_meshes[i].subMeshes[j].material = new TextureMaterial(texturas[layer_tex], true,true);
								_meshes[i].subMeshes[j].material.bothSides = true;
							}
							
							
						}
						
						
						//var mat:Matrix3D = new Matrix3D();
						//mat.appendTranslation(300,200,1000);
						//_meshes[i].transform = mat;
						//_meshes[i].moveForward(1000);
						//finalizeAsset(_meshes[i]);
					}
					
				}
				
			}
			else {
				
				if (resourceDependency.assets.length != 1)
					return;
				
				
				var asset : Texture2DBase = resourceDependency.assets[0] as Texture2DBase;
				
				var idtext:int = texturasID.indexOf(resourceDependency.id);
				
				if(idtext == -1 || asset == null)
					return;
				
				texturas[idtext] = asset;
				
							
				for (i = 0; i < texturaXMesh.length; i++) 
				{
					if(texturaXMesh[i] == idtext)
					{
						_meshes[i].subMeshes[0].material = new TextureMaterial(asset, true, true);
						_meshes[i].subMeshes[0].material.bothSides = true;
						//trace(Globals.lights);
						//_meshes[i].subMeshes[0].material.lightPicker = new StaticLightPicker(MG3DGlobals.lights);
						//((_meshes[i].subMeshes[0].material) as TextureMaterial).shadowMethod = MG3DGlobals.shadowMethod;
						
					}
					
				}
				
			}
		}
		
		/**
		* @inheritDoc
		*/
		override arcane function resolveDependencyFailure(resourceDependency:ResourceDependency):void
		{
			
		}
		
		/**
		* @inheritDoc
		*/
		override protected function proceedParsing() : Boolean
		{
			if(!_startedParsing)
				_textData = getTextData();
			
			
			if(!_startedParsing){
				_startedParsing = true;
				_materialIDs = new Vector.<String>();
				_meshes = new Vector.<Mesh>();
				
				clearMeshData();
				
				_stringLength = _textData.length;
				_charIndex = 0;
				_oldIndex = 0;
				_objectIndex = 0;
			}
			
			if (!_parsedTextures) {
				parseTextures();
			}				
			else
			{
				if (!_parsedMeshes)
				{
					parseMeshes();
				}
				else
				{
					if (!_parsedFaces)
					{
						parseFaces();
					}
					else
					{
						return PARSING_DONE;
					}								
					
				}
			}
			
			return MORE_TO_PARSE;
		}
		
		private function clearMeshData():void
		{
			// TODO Auto Generated method stub
			_vertices = new Vector.<Number>();
			_vertexNormals = new Vector.<Number>();
			_uvs = new Vector.<Number>();
			_indices = new Vector.<uint>();
			
		}
		
		protected function parseFaces():void
		{
			//Faces
			//<FACES>
			var lineTokens:Array = getLineTokens();
			
			// Cantidad de Faces
			lineTokens = getLineTokens();
			_cant_faces = parseInt(lineTokens[0]);
			for (var i:int = 0; i < _cant_faces; i++)
			{
				layersXMesh.push(null);
				
				//<FACE {i+1}>
				lineTokens = getLineTokens();
				
				//tipo Face, Triangulo(3) o Rectangulo(1)
				lineTokens = getLineTokens();
				var tipo_face:int = parseInt(lineTokens[0]);
				
				for (var j:int = 0; j < 4; j++)
				{
					//Vertices
					
					//Posicion
					lineTokens = getLineTokens();
					if(tipo_face == 1 || j < 4)						
						parsePosition(lineTokens);
					
					//Normal
					lineTokens = getLineTokens();
					if(tipo_face == 1 || j < 4)
						parseNormals(lineTokens);
					
					//UV
					lineTokens = getLineTokens();
					if(tipo_face == 1 || j < 4)
						parseUVs(lineTokens);
					
					//color					
					lineTokens = getLineTokens();
					var color :uint = parseInt(lineTokens[0]);
					
				}
				
				addTriagleIndex(0,1,2);
				if (tipo_face == 1)
					//rectangulo
					addTriagleIndex(0,2,3);
				
				//id
				lineTokens = getLineTokens();
				var face_id:int = parseInt(lineTokens[0]);
				
				// Borde
				// Esta variable deberia ser BYTE
				lineTokens = getLineTokens();
				var borde:int = parseInt(lineTokens[0]);
				
				//nro_mesh, -1 si no es mesh
				lineTokens = getLineTokens();
				var nro_mesh:int = parseInt(lineTokens[0]);
				
				//nro de textura
				lineTokens = getLineTokens();
				var nro_textura:int = parseInt(lineTokens[0]);
				
				// parametros de iluminacion
				lineTokens = getLineTokens();
				var kd:Number = parseFloat(lineTokens[0]);
				var ks:Number = parseFloat(lineTokens[1]);
				var kr:Number = parseFloat(lineTokens[2]);
				var kt:Number = parseFloat(lineTokens[3]);
				
				var world : Matrix3D = new Matrix3D();
				if(nro_mesh != -1)
				{
					//es un mesh
					//<MESH_INSTANCE {idmesh}>
					lineTokens = getLineTokens();
					
					//Cant Layers
					lineTokens = getLineTokens();
					var cant_layers:int = parseInt(lineTokens[0]);
					
					//WordMatrix
					var row1:Array, row2:Array, row3:Array, row4:Array;
					row1 = getLineTokens();
					row2 = getLineTokens();
					row3 = getLineTokens();
					row4 = getLineTokens();
					world = parseMatrix(row1, row2, row3, row4);
					
					
					var texXLayer: Vector.<int> = new Vector.<int>();
					//layers
					for(j = 0; j < cant_layers; j++)
					{
						//nro layer
						lineTokens = getLineTokens();
						var nro_layer:int = parseInt(lineTokens[0]);
						
						//ambient color
						lineTokens = getLineTokens();
						//Vector4 ambient = parseVector4(lineTokens);
						
						//diffuse color
						lineTokens = getLineTokens();
						//Vector4 diffuse = ParseVector4(lineTokens);
						
						//specular color
						lineTokens = getLineTokens();
						//Vector4 specular = ParseVector4(lineTokens);
						
						//Coefcientes luz
						lineTokens = getLineTokens();
						var l_kr:Number = parseFloat(lineTokens[0]);
						var l_ks:Number = parseFloat(lineTokens[1]);
						
						//textura Propia
						lineTokens = getLineTokens();
						var textura_propia:int = parseInt(lineTokens[0]);
						
						//Nro Textura
						lineTokens = getLineTokens();
						var l_nro_textura:int = parseInt(lineTokens[0]);
						
						//if (l_nro_textura >= 0 && l_nro_textura < textures.Count && textura_propia > 0 && textures[l_nro_textura] != null)
						//meshPool[nro_mesh].Subsets[i].Texture = textures[l_nro_textura];
						//    meshPool[nro_mesh].Subsets[i].Texture = Globals.Instance.TexturePool.Textures[l_nro_textura];
						
						texXLayer.push(textura_propia? l_nro_textura : -1);
						
					}
					
					layersXMesh[i] = texXLayer;
					
					//Fin mesh
					//</MESH_INSTANCE>
					lineTokens = getLineTokens();;
					
				}

				
				//Fin Face
				//</FACE>
				lineTokens = getLineTokens();
				
				//aca se crea el mesh
				
				//MeshSubset ms = new MeshSubset(2, 4, 0, 0, VertexPositionColorNormalTexture.VertexDeclaration, device);
				//ms.VertexBuffer.SetData(vertices);
				
				/*ushort [] index;
				if (tipo_face == 1)
					//rectangulo
					index = new ushort[] { 0, 1, 2, 0, 2, 3 };
				else
				{
					//triangulo, Repito dos veces el mismo triangulo
					index = new ushort[] { 0, 1, 2, 0, 1, 2 };
					//piso el vertice que esta en 0,0,0 para que no arruine el boundingbox
					vertices[3] = vertices[0];
				}
				
				ms.IndexBuffer.SetData(index);
				
				if (nro_textura >= 0)
					//ms.Texture = textures[nro_textura];
					ms.Texture = Globals.Instance.TexturePool.Textures[nro_textura];
				Mesh mesh = new Mesh();
				mesh.Subsets.Add(ms);
				mesh.BoundingBox = BoundingBox.CreateFromPoints(MeshUtils.getVertexPositions(vertices));
				
				if (nro_mesh == -1)
					meshes.Add(mesh);
				else
				{
					//meshes
					//Mesh m = new Mesh();
					//m.Subsets = meshPool[nro_mesh].Subsets;
					mesh.Subsets = Globals.Instance.MeshPool.Meshes[nro_mesh].Subsets;
					mesh.worldMatrix = world;
					
					meshes.Add(mesh);
				}*/
				
				texturaXMesh.push(nro_textura);
				meshXMesh.push(nro_mesh);
				worldmatXMesh.push(world);
				
				buildMesh();
				
			}
			
			_parsedFaces = true;
			
		}
		
		private function addTriagleIndex(i0:uint, i1:uint, i2:uint):void
		{
			_indices.push(i0);
			_indices.push(i1);
			_indices.push(i2);
		}
		
		private function buildMesh():void
		{
			// TODO Auto Generated method stub
			var mesh:Mesh;
			var geometry: Geometry = new Geometry();
			var subGeometry : SubGeometry = new SubGeometry();
			
			subGeometry.updateVertexData(_vertices);
			subGeometry.updateIndexData(_indices);
			subGeometry.updateUVData(_uvs);
			subGeometry.updateVertexNormalData(_vertexNormals);
			
			geometry.addSubGeometry(subGeometry);
			mesh = new Mesh(geometry);
			mesh.material = new TextureMaterial( DefaultMaterialManager.getDefaultTexture(), true, true );
			//mesh.material = new ColorMaterial(100*_meshes.length);
			mesh.material.bothSides = true;
			
			mesh.name = "face-"+_meshes.length;
			_meshes.push(mesh);
			
			//vacio los vectores
			clearMeshData();
			
			//if (meshXMesh[meshXMesh.length-1] == 4)
			finalizeAsset(mesh);
			
		}
		
		protected function parseMeshes():void
		{
			//Meshes
			//<MESHES>
			var lineTokens:Array = getLineTokens();
			
			//cantidad de meshes
			lineTokens = getLineTokens();
			_cant_meshes = parseInt(lineTokens[0]);
			for (var i:int = 0; i < _cant_meshes; i++)
			{
				//Meshes Path
				lineTokens = getLineTokens();
				
				var file:String = FilePath.ChangeExtension(lineTokens[0], ".y");
				//saco el fullpath
				file = file.substring(file.lastIndexOf("texturas") + 9);
				
				meshesID.push(lineTokens[0]);
				addDependency(lineTokens[0], new URLRequest(MG3DGlobals.TEXTURE_FOLDER + file));
				
				//string path = @"c:\test\" + Path.GetFileNameWithoutExtension(lineTokens[0]) + ".y";
				//string path = lineTokens[0];
				//meshPool.Add(YLoader.FromFile(path));
				//Globals.Instance.MeshPool.GetTexture(path);
				
				
				//TODO: Por el momento no se hace nada
			}
			//Fin Meshes
			//</MESHES>
			lineTokens = getLineTokens();
			
			_parsedMeshes = true;
		}
		
		protected function parseTextures():void
		{
			//Texturas
			//primera linea <TEXTURAS>
			var lineTokens:Array = getLineTokens();
			
			//cantidad de texturas
			lineTokens = getLineTokens();
			_cant_texturas = parseInt(lineTokens[0]);
			for(var i:int = 0 ; i < _cant_texturas; i++)
			{
				//Texture Path
				lineTokens = getLineTokens();
				
				//saco el fullpath
				var file:String = lineTokens[0];
				file = file.substring(file.lastIndexOf("texturas") + 9);				
				
				texturasID.push(lineTokens[0]);
				texturas.push(null);
				
				if(FilePath.GetExtension(file).toLowerCase() != ".msh")
				{
					file = FilePath.ChangeExtension(file,".jpg");
					addDependency(lineTokens[0], new URLRequest(MG3DGlobals.TEXTURE_FOLDER + file));
				}
				
				
				//Texture2D tex = ResourceUtils.GetTexture(Globals.Instance.D3dDevice, lineTokens[0]);
				//textures.Add(tex);
				//	Globals.Instance.TexturePool.GetTexture(lineTokens[0]);
			}
			
			//Fin Texturas
			//</TEXTURAS>
			lineTokens = getLineTokens();
			_parsedTextures = true;
			
		}
		
		protected function getLineTokens():Array
		{
			_charIndex = _textData.indexOf("\r", _oldIndex);
			
			if(_charIndex == -1)
				_charIndex = _textData.indexOf("\n", _oldIndex);
			
			if(_charIndex == -1)
				_charIndex = _stringLength;
			
			var line:String = _textData.substring(_oldIndex, _charIndex);
			line = line.replace("\r","").replace("\n","").replace(/\[/g, "").replace(/\]/g, "").replace(/\"/g,"");
			
			_oldIndex = _charIndex + 1;
			
			return line.split(",");
		}
		
		
		protected function parsePosition(tokens : Array ) : void
		{
			var x:Number = parseFloat(tokens[1]);
			var y:Number = parseFloat(tokens[2]);
			var z:Number = parseFloat(tokens[0]);
			
			_vertices.push(x);
			_vertices.push(y);
			_vertices.push(-z);
		}
		
		protected function parseNormals(tokens : Array ) : void
		{
			var x:Number = parseFloat(tokens[1]);
			var y:Number = parseFloat(tokens[2]);
			var z:Number = parseFloat(tokens[0]);
			
			_vertexNormals.push(x);
			_vertexNormals.push(y);
			_vertexNormals.push(-z);
		}
		
		protected function parseUVs(tokens : Array ) : void
		{
			var u:Number = parseFloat(tokens[0]);
			var v:Number = parseFloat(tokens[1]);
			
			
			_uvs.push(u);
			_uvs.push(v);
		}
		
		protected function parseMatrix(row1:Array, row2:Array, row3:Array, row4:Array):Matrix3D
		{
			/*return new Matrix(
			ParseFloat(row1[0]), ParseFloat(row1[1]), ParseFloat(row1[2]), ParseFloat(row1[3]),
			ParseFloat(row2[0]), ParseFloat(row2[1]), ParseFloat(row2[2]), ParseFloat(row2[3]),
			ParseFloat(row3[0]), ParseFloat(row3[1]), ParseFloat(row3[2]), ParseFloat(row3[3]),
			ParseFloat(row4[0]), ParseFloat(row4[1]), ParseFloat(row4[2]), ParseFloat(row4[3])
			);*/
			/*return new Matrix(
				ParseFloat(row1[0]), ParseFloat(row1[2]), ParseFloat(row1[1]), ParseFloat(row1[3]),
				ParseFloat(row3[0]), ParseFloat(row3[2]), ParseFloat(row2[2]), ParseFloat(row2[3]),
				ParseFloat(row2[0]), ParseFloat(row3[1]), ParseFloat(row2[1]), ParseFloat(row3[3]),
				ParseFloat(row4[0]), ParseFloat(row4[2]), ParseFloat(row4[1]), ParseFloat(row4[3])
			);*/
			
			
			var matdata : Vector.<Number> = Vector.<Number>([
				parseFloat(row1[0]), parseFloat(row1[2]), -parseFloat(row1[1]), parseFloat(row1[3]),
				parseFloat(row3[0]), parseFloat(row3[2]), parseFloat(row2[2]), parseFloat(row2[3]),
				-parseFloat(row2[0]), parseFloat(row3[1]), parseFloat(row2[1]), parseFloat(row3[3]),
				parseFloat(row4[0]), parseFloat(row4[2]), -parseFloat(row4[1]), parseFloat(row4[3])
			]);
			
			var mat:Matrix3D = new Matrix3D(matdata)
			
			return mat;			
			
		}
		
	}
}
		

