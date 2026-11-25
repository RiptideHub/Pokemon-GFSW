def saveMapScreenShot(mapid)
  map=load_data(sprintf("Data/Map%03d.rxdata",mapid)) rescue nil
  return BitmapWrapper.new(32,32) if !map
  bitmap=BitmapWrapper.new(map.width*32,map.height*32)
  black=Color.new(0,0,0)
  tilesets=load_data("Data/Tilesets.rxdata")
  tileset=tilesets[map.tileset_id]
  return bitmap if !tileset
  helper=TileDrawingHelper.fromTileset(tileset)
  for y in 0...map.height
    for x in 0...map.width
      for z in 0..2
        id=map.data[x,y,z]
        id=0 if !id
        helper.bltTile(bitmap,x*32,y*32,id)
      end
    end
  end
  bitmap.to_file(sprintf("Map%03d.png",mapid))
end