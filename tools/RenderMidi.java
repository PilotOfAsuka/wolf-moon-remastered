import com.sun.media.sound.AudioSynthesizer;
import javax.sound.midi.*;
import javax.sound.sampled.*;
import java.io.*;
import java.util.*;

/** Offline Gervill rendering of the user's extracted MIDI. No replacement music. */
public final class RenderMidi {
    record Event(long tick, MidiMessage message) {}
    public static void main(String[] args) throws Exception {
        Sequence sequence = MidiSystem.getSequence(new File(args[0]));
        if(sequence.getDivisionType()!=Sequence.PPQ) throw new IllegalArgumentException("Expected PPQ");
        AudioSynthesizer synth = (AudioSynthesizer)MidiSystem.getSynthesizer();
        AudioFormat format = new AudioFormat(22050,16,2,true,false);
        Map<String,Object> options = new HashMap<>(); options.put("interpolation","linear");
        AudioInputStream stream = synth.openStream(format,options);
        Receiver receiver = synth.getReceiver();
        List<Event> events = new ArrayList<>();
        for(Track track: sequence.getTracks()) for(int i=0;i<track.size();i++) {
            MidiEvent event=track.get(i); events.add(new Event(event.getTick(),event.getMessage()));
        }
        events.sort(Comparator.comparingLong(Event::tick));
        long tick=0, micros=0; int tempo=500000;
        for(Event event:events) {
            micros+=(event.tick()-tick)*tempo/sequence.getResolution(); tick=event.tick();
            if(event.message() instanceof MetaMessage meta) {
                if(meta.getType()==0x51) {
                    byte[] b=meta.getData(); tempo=((b[0]&255)<<16)|((b[1]&255)<<8)|(b[2]&255);
                }
            } else receiver.send(event.message(),micros);
        }
        long frames=(long)((micros/1e6+2.0)*format.getFrameRate());
        AudioSystem.write(new AudioInputStream(stream,format,frames),AudioFileFormat.Type.WAVE,new File(args[1]));
        synth.close();
        System.out.printf("%s: %.3fs, %d events%n",args[0],micros/1e6,events.size());
    }
}
