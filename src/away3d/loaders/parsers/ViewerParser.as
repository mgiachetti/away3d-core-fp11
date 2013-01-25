package away3d.loaders.parsers
{
	import away3d.arcane;
	import away3d.containers.ObjectContainer3D;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.entities.Mesh;
	import away3d.events.AssetEvent;
	import away3d.library.assets.IAsset;
	import away3d.loaders.misc.ResourceDependency;
	import away3d.materials.ColorMaterial;
	import away3d.materials.DefaultMaterialBase;
	import away3d.materials.MaterialBase;
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
	import away3d.tools.commands.Merge;
	
	import com.mgsoft.mg3dengine.FilePath;
	import com.mgsoft.mg3dengine.MG3DGlobals;
	import com.mgsoft.mg3dengine.MGColorUtils;
	import com.mgsoft.mg3dengine.MGMaterial;
	import com.mgsoft.mg3dengine.MGMeshPool;
	import com.mgsoft.mg3dengine.MGTexturePool;
	
	import flash.geom.Matrix3D;
	import flash.net.FileReference;
	import flash.net.URLRequest;
	import flash.sampler.NewObjectSample;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.getTimer;
	
	import flashx.textLayout.factory.TruncationOptions;
	
	import mx.collections.ArrayList;
	
	import spark.primitives.Path;
	

	use namespace arcane;
	
	/**
	 * OBJParser provides a parser for the OBJ data type.
	 */
	public class ViewerParser extends ParserBase
	{
		private var _byteData:ByteArray;
		
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
		private var _color : uint;
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
		private var meshesRequest:ArrayList = new ArrayList();
		private var meshXMesh:Vector.<int> = new Vector.<int>();
		private var worldmatXMesh:Vector.<Matrix3D> = new Vector.<Matrix3D>();
		private var layersXMesh:Vector.<Vector.<int>> = new Vector.<Vector.<int>>();
		private var layersMatXMesh:Vector.<Vector.<MGMaterial>> = new Vector.<Vector.<MGMaterial>>();
		private var texturas: Vector.<TextureMaterial> = new Vector.<TextureMaterial>();
		public var _objectContainer : ObjectContainer3D = new ObjectContainer3D(); //toda la escena queda cargada en este objectcontainer 
		
		/**
		 * Loads a Viewer.dat Lepton File.
		 */
		public function ViewerParser()
		{
			super(ParserDataFormat.BINARY);			
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
		}
		
		public function resolveMesh(event : AssetEvent):void
		{
			var mesh : Mesh = event.asset as Mesh;
			
			mesh.disposable = false;
			
			var idMesh:int = meshesID.indexOf(event.assetPrevName);
						
			if(idMesh != -1)
				meshesRequest.removeItem(event.assetPrevName);
			
			if(meshesRequest.length == 0)
			{
				//Ya se cargaron todas las dependencias de mesh elimino el listener para que no me lleguen ecos de otros pedidos
				MGMeshPool.removeEnventListener(AssetEvent.ASSET_COMPLETE, resolveMesh);
			}
			
			if(idMesh == -1 || mesh == null)
				return;
			
			meshesID[idMesh] = "";
			
			var mlength : int =  meshXMesh.length;
			for (var i:int = 0; i < mlength; i++) 
			{
				if(meshXMesh[i] == idMesh)
				{
					_meshes[i].geometry = mesh.geometry;
					_meshes[i].material = mesh.material;
					_meshes[i].bounds = mesh.bounds;
					_meshes[i].pivotPoint = mesh.pivotPoint;
					_meshes[i].partition = mesh.partition;
					_meshes[i].transform = worldmatXMesh[i];
					_meshes[i].showBounds = false;
					_meshes[i].disposable = false;
					
					var slength : int = _meshes[i].subMeshes.length;
					for (var j:int = 0; j < slength; j++) 
					{
						var layer_tex : int = -1;
						var mat : MGMaterial = null;
						var nro_layer:int = _meshes[i].geometry.subGeometries[j].nroLayer;
						
						var llength : int = layersXMesh[i].length;
						if(nro_layer < llength)
						{
							layer_tex = layersXMesh[i][nro_layer];
							mat = layersMatXMesh[i][nro_layer];
						}
						
						//var layer_tex : int = -1;
						if(layer_tex == -1)
						{
							_meshes[i].subMeshes[j].material = mesh.subMeshes[j].material;							
							_meshes[i].subMeshes[j].material.bothSides = true;
						}
						else
						{
							//tiene una textura propia el layer
							_meshes[i].subMeshes[j].material = texturas[layer_tex];
							_meshes[i].subMeshes[j].material.bothSides = true;
						}
						
						if(mat != null)
						{
							var material : DefaultMaterialBase = _meshes[i].subMeshes[j].material as DefaultMaterialBase;
							material.ambientColor = mat.Ambient;
							material.specularColor = mat.Specular;
							var alpha : Number = MGColorUtils.getA(mat.Ambient)/255.0;
							if(material is ColorMaterial)
							{
								(material as ColorMaterial).color = mat.Ambient;
								(material as ColorMaterial).alpha = alpha;
								//(material as ColorMaterial).alpha = 1-mat.TransparencyLevel;
							}
							else
								//(material as TextureMaterial).alpha = 1-mat.TransparencyLevel;
								(material as TextureMaterial).alpha = alpha;
						}
						 
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
			{
				_byteData = getByteData();
				_byteData.endian = Endian.LITTLE_ENDIAN;
				//(new FileReference()).save(_byteData,"escenaBIN.dat");
				//return true;
			}
			
			
			if(!_startedParsing){
				_startedParsing = true;
				_materialIDs = new Vector.<String>();
				_meshes = new Vector.<Mesh>();
				
				clearMeshData();
				
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
						MergeMeshes();
						fetchMeshes();
						return PARSING_DONE;
					}								
					
				}
			}
			
			return MORE_TO_PARSE;
		}
		
		private function fetchMeshes():void
		{
			if(meshesID.length == 0)
				return;
			
			MGMeshPool.addEventListener(AssetEvent.ASSET_COMPLETE,resolveMesh);
			
			for each (var m : String in meshesID)
				meshesRequest.addItem(m);
			
			for each (m in meshesID)
			{
				//var file:String = FilePath.ChangeExtension(m, ".y");
				//saco el fullpath
				//file = file.substring(file.lastIndexOf("texturas") + 9);
				
				MGMeshPool.getMesh(m);
			}
			
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
			// Cantidad de Faces
			
			_cant_faces = _byteData.readInt();
			for (var i:int = 0; i < _cant_faces; i++)
			{
				layersXMesh.push(null);
				layersMatXMesh.push(null);
				
				//tipo Face, Triangulo(3) o Rectangulo(1)
				var tipo_face:int = _byteData.readByte();
				
				//3 byte de relleno (alineacion)
				_byteData.readByte();
				_byteData.readByte();
				_byteData.readByte();
				
				for (var j:int = 0; j < 4; j++)
				{
					//Vertices
					
					//Posicion
					if(tipo_face == 1 || j < 4)						
						parsePosition();
					
					//Normal
					if(tipo_face == 1 || j < 4)
						parseNormals();
					
					//color					
					_color = _byteData.readUnsignedInt();
					
					//UV
					if(tipo_face == 1 || j < 4)
						parseUVs();
					
				}
				
				addTriagleIndex(0,1,2);
				if (tipo_face == 1)
					//rectangulo
					addTriagleIndex(0,2,3);
				
				//id
				var face_id:int = _byteData.readInt();
				
				// Borde
				// Esta variable deberia ser BYTE
				var borde:int = _byteData.readByte();
				
				//3 byte de relleno (alineacion)
				_byteData.readByte();
				_byteData.readByte();
				_byteData.readByte();
				
				//nro_mesh, -1 si no es mesh
				var nro_mesh:int = _byteData.readInt();
				
				//nro de textura
				var nro_textura:int = _byteData.readByte();
				
				//3 byte de relleno (alineacion)
				_byteData.readByte();
				_byteData.readByte();
				_byteData.readByte();
				
				// parametros de iluminacion
				var kd:Number = _byteData.readFloat();
				var ks:Number = _byteData.readFloat();
				var kr:Number = _byteData.readFloat();
				var kt:Number = _byteData.readFloat();
				
				var world : Matrix3D = new Matrix3D();
				if(nro_mesh != -1)
				{
					//es un mesh
					//<MESH_INSTANCE {idmesh}>

					//Cant Layers
					var cant_layers:int = _byteData.readByte();
					
					//3 byte de relleno (alineacion)
					_byteData.readByte();
					_byteData.readByte();
					_byteData.readByte();
					
					//WordMatrix
					world = parseMatrix();
					
					var texXLayer: Vector.<int> = new Vector.<int>();
					var matXLayer: Vector.<MGMaterial> = new Vector.<MGMaterial>();
					//layers
					for(j = 0; j < cant_layers; j++)
					{
						//nro layer
						var nro_layer:int = _byteData.readByte();
						
						//3 byte de relleno (alineacion)
						_byteData.readByte();
						_byteData.readByte();
						_byteData.readByte();
						
						//material
						var mat : MGMaterial = new MGMaterial();
						mat.Diffuse = MGColorUtils.colorFromARGB(_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255);
						mat.Ambient = MGColorUtils.colorFromARGB(_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255);
						mat.Specular = MGColorUtils.colorFromARGB(_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255);
						mat.Emissive = MGColorUtils.colorFromARGB(_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255);
						mat.Power = _byteData.readFloat();
						
						//Coefcientes luz
						mat.TransparencyLevel = _byteData.readFloat();
						mat.SpecularLevel = _byteData.readFloat();
						
						//textura Propia
						var textura_propia:int = _byteData.readByte();
						
						//Nro Textura
						var l_nro_textura:int = _byteData.readByte();
						
						//2 byte de relleno (alineacion)
						_byteData.readByte();
						_byteData.readByte();
						
						//if (l_nro_textura >= 0 && l_nro_textura < textures.Count && textura_propia > 0 && textures[l_nro_textura] != null)
						//meshPool[nro_mesh].Subsets[i].Texture = textures[l_nro_textura];
						//    meshPool[nro_mesh].Subsets[i].Texture = Globals.Instance.TexturePool.Textures[l_nro_textura];
						
						if(textura_propia == 0)
							mat = null;
						
						texXLayer.push(textura_propia? l_nro_textura : -1);
						matXLayer.push(mat);
					}
					
					layersXMesh[i] = texXLayer;
					layersMatXMesh[i] = matXLayer;
					
					//Fin mesh
					//</MESH_INSTANCE>
				}

				
				//Fin Face
				//</FACE>
				
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
			var start : int = getTimer();
			var mesh:Mesh;
			var geometry: Geometry = new Geometry();
			var subGeometry : SubGeometry = new SubGeometry();
			
			subGeometry.updateVertexData(_vertices);
			subGeometry.updateIndexData(_indices);
			subGeometry.updateUVData(_uvs);
			subGeometry.updateVertexNormalData(_vertexNormals);
			
			geometry.addSubGeometry(subGeometry);
			mesh = new Mesh(geometry);
			//mesh.material = new TextureMaterial( DefaultMaterialManager.getDefaultTexture(), true, true );
			var tex_ind : int = texturaXMesh[texturaXMesh.length-1];
			mesh.material = tex_ind >= 0 ? texturas[tex_ind] : new ColorMaterial(_color, MGColorUtils.getA(_color)/255.0);
			if(mesh.material is TextureMaterial)
			{
				(mesh.material as TextureMaterial).alpha = MGColorUtils.getA(_color)/255.0;
			}
			//mesh.material = new ColorMaterial(100*_meshes.length);
			//mesh.material.bothSides = true;
			
			mesh.name = "face-"+_meshes.length;
			_meshes.push(mesh);
			
			//vacio los vectores
			clearMeshData();
			
			//trace("BuildMesh: "+ (getTimer() - start));
			
			//if (meshXMesh[meshXMesh.length-1] == 4)
			//finalizeAsset(mesh);
			
		}
		
		private function MergeMeshes():void
		{
			// TODO Auto Generated method stub
			var start : int = getTimer();
			var merge : Merge = new Merge(true);
			var bigMesh : Mesh = new Mesh(new Geometry());
			var meshes : Vector.<Mesh> = new Vector.<Mesh>();
			
			for (var i:int = 0; i < meshXMesh.length; i++) 
			{
				if(meshXMesh[i] != -1)
				{
					//finalizeAsset(_meshes[i]);
					_objectContainer.addChild(_meshes[i]);
					continue;
				}
				
				meshes.push(_meshes[i]);
			}
			
			merge.applyToMeshes(bigMesh, meshes);
			
			trace("Merge: "+ (getTimer() - start));
			
			_objectContainer.addChild(bigMesh);
			//finalizeAsset(bigMesh);
			finalizeAsset(_objectContainer);
		}
		
		protected function parseMeshes():void
		{
			//Meshes
			//<MESHES>
			
			//cantidad de meshes
			_cant_meshes = _byteData.readInt();
			for (var i:int = 0; i < _cant_meshes; i++)
			{
				//Meshes Path
					
				var file:String = _byteData.readMultiByte(260, "iso-8859-1");
				
				file = FilePath.ChangeExtension(file, ".y");
				//saco el fullpath
				//file = file.substring(file.lastIndexOf("texturas") + 9);
				file = file.substring(file.lastIndexOf("texturas"));
				//file = MG3DGlobals.TEXTURE_FOLDER + file
				
				//meshesID.push(lineTokens[0]);
				meshesID.push(file);
				//addDependency(lineTokens[0], new URLRequest(MG3DGlobals.TEXTURE_FOLDER + file));
				
				//string path = @"c:\test\" + Path.GetFileNameWithoutExtension(lineTokens[0]) + ".y";
				//string path = lineTokens[0];
				//meshPool.Add(YLoader.FromFile(path));
				//Globals.Instance.MeshPool.GetTexture(path);
				
				
				//TODO: Por el momento no se hace nada
			}
			//Fin Meshes
			//</MESHES>
			
			_parsedMeshes = true;
		}
		
		protected function parseTextures():void
		{
			//primero parseo el Header
			var head : String = _byteData.readMultiByte(10, "iso-8859-1"); // aca tiene que decir LEPTONVIEW
			var version : int =  _byteData.readInt(); // version 1;
			
			//Texturas
			//primera linea <TEXTURAS>
			
			//cantidad de texturas
			_cant_texturas = _byteData.readInt();
			for(var i:int = 0 ; i < _cant_texturas; i++)
			{
				//Texture Path
				
				//saco el fullpath
				var fileName:String = _byteData.readMultiByte(260, "iso-8859-1");
				var bmp_k : int = _byteData.readInt();
				
				var file:String = fileName;
				file = file.substring(file.lastIndexOf("texturas") + 9);				
				
				texturasID.push(fileName);
				texturas.push(null);
				
				var ext : String = FilePath.GetExtension(file).toLowerCase();
				if(ext != ".msh" && ext != ".dxf" && ext != ".x")
				{
					//addDependency(lineTokens[0], new URLRequest(MG3DGlobals.TEXTURE_FOLDER + file));
					texturas[texturas.length-1] = MGTexturePool.getTexture(MG3DGlobals.TEXTURE_FOLDER + file);
				}
				
			}
			
			//Fin Texturas
			//</TEXTURAS>
			_parsedTextures = true;
			
		}
		
		protected function parsePosition() : void
		{
			var x:Number = _byteData.readFloat();
			var z:Number = _byteData.readFloat();
			var y:Number = _byteData.readFloat();
			
			//var z:Number = _byteData.readFloat();
			//var x:Number = _byteData.readFloat();
			//var y:Number = _byteData.readFloat();
			
			_vertices.push(x);
			_vertices.push(y);
			_vertices.push(-z);
		}
		
		protected function parseNormals() : void
		{
			var x:Number = _byteData.readFloat();
			var z:Number = _byteData.readFloat();
			var y:Number = _byteData.readFloat();
			
			_vertexNormals.push(x);
			_vertexNormals.push(y);
			_vertexNormals.push(-z);
		}
		
		protected function parseUVs() : void
		{
			var u:Number = _byteData.readFloat();
			var v:Number = _byteData.readFloat();
			
			_uvs.push(u);
			_uvs.push(v);
		}
		
		protected function parseMatrix():Matrix3D
		{
			
			/*var matdata : Vector.<Number> = Vector.<Number>([
				parseFloat(row1[0]), parseFloat(row1[2]), -parseFloat(row1[1]), parseFloat(row1[3]),
				parseFloat(row3[0]), parseFloat(row3[2]), parseFloat(row2[2]), parseFloat(row2[3]),
				-parseFloat(row2[0]), parseFloat(row3[1]), parseFloat(row2[1]), parseFloat(row3[3]),
				parseFloat(row4[0]), parseFloat(row4[2]), -parseFloat(row4[1]), parseFloat(row4[3])
			]);*/
			
			
			var rows : Vector.<Vector.<Number>> = new Vector.<Vector.<Number>>();
			
			for(var i : int = 0 ; i < 4 ; i++)
			{
				rows.push(new Vector.<Number>());
				for(var j : int = 0 ; j < 4 ; j++)
				{
					rows[i].push(_byteData.readFloat());			
				}
			}
			
			var matdata : Vector.<Number> = Vector.<Number>([
				rows[0][0], rows[0][2], -rows[0][1], rows[0][3],
				rows[2][0], rows[2][2], -rows[2][1], rows[1][3],
				-rows[1][0], -rows[1][2], rows[1][1], rows[2][3],
				rows[3][0], rows[3][2], -rows[3][1], rows[3][3]
			]);
			
			var mat:Matrix3D = new Matrix3D(matdata)
			
			return mat;			
		}
		
	}
}
		

